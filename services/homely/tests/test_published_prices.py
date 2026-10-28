import json
from datetime import datetime,timedelta,timezone,date
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from zoneinfo import ZoneInfo

from controller.service import State,validate_published_prices,fetch_controller_prices,fetch_radiation
from homely import fetch_agile_prices,validate_agile_day
from test_heating_boost import prices

UTC=timezone.utc
LONDON=ZoneInfo('Europe/London')
DAY=date(2026,10,25)
NOW=datetime(2026,10,25,8,tzinfo=UTC)

class FixedDatetime(datetime):
    @classmethod
    def now(cls,tz=None): return NOW.astimezone(tz or UTC)

class PublishedPriceTests(unittest.TestCase):
    def test_fall_back_published_tail_is_usable_until_coverage_end(self):
        rates=prices(DAY)[:48]
        self.assertEqual(len(validate_published_prices(rates,DAY,LONDON,NOW)),48)
        with self.assertRaises(ValueError):
            validate_published_prices(rates,DAY,LONDON,rates[-1]['end'].astimezone(UTC))
        with self.assertRaises(RuntimeError):validate_agile_day(rates,DAY,LONDON)

    def test_complete_spring_and_autumn_days(self):
        for day,n in [(date(2026,3,29),46),(DAY,50)]:
            now=datetime.combine(day,datetime.min.time(),LONDON).astimezone(UTC)+timedelta(hours=8)
            self.assertEqual(len(validate_published_prices(prices(day),day,LONDON,now)),n)

    def test_interior_missing_duplicate_overlap_and_bad_price_still_fail(self):
        for issue in ('first','interior','duplicate','overlap','nan','too_short'):
            rows=prices(DAY)[:48]
            if issue=='first':rows.pop(0)
            elif issue=='interior':rows.pop(4)
            elif issue=='duplicate':rows.append(rows[4])
            elif issue=='overlap':rows[4]['end']=rows[5]['end']
            elif issue=='nan':rows[4]['price']=float('nan')
            else:rows=rows[:2]
            with self.subTest(issue=issue),self.assertRaises(ValueError):
                validate_published_prices(rows,DAY,LONDON,NOW)

    def test_shared_retrieval_stays_strict_for_hot_water_by_default(self):
        rows=prices(DAY)[:48]
        body=json.dumps({'results':[{'valid_from':r['start'].astimezone(UTC).isoformat(),
            'valid_to':r['end'].astimezone(UTC).isoformat(),'value_inc_vat':r['price']} for r in rows]})+'\n200'
        response=SimpleNamespace(returncode=0,stdout=body,stderr='')
        with patch('homely.shutil.which',return_value='curl'),patch('homely.subprocess.run',return_value=response):
            with self.assertRaises(RuntimeError):fetch_agile_prices('product','tariff',DAY,LONDON)
            self.assertEqual(len(fetch_agile_prices('product','tariff',DAY,LONDON,require_complete_day=False)),48)

    def test_controller_requests_raw_rates_then_validates_current_coverage(self):
        with patch('controller.service.fetch_agile_prices',return_value=prices(DAY)[:48]) as get:
            self.assertEqual(len(fetch_controller_prices('product','tariff',DAY,LONDON,now=NOW)),48)
            self.assertEqual(get.call_args.kwargs,{'require_complete_day':False})

    def test_refresh_reports_partial_horizon_and_usable_current_price(self):
        with tempfile.TemporaryDirectory() as directory:
            state=State(Path(directory)/'policy.json')
            doc=state.document();doc['policy'].update(product='AGILE-EXAMPLE',tariff='E-1R-AGILE-EXAMPLE-G')
            state.update(doc)
            for rows,complete in [(prices(DAY)[:48],False),(prices(DAY),True)]:
                with patch('controller.service.datetime',FixedDatetime),patch('controller.service.fetch_agile_prices',return_value=rows),patch('controller.service.fetch_radiation',return_value={r['start'].astimezone(UTC):0 for r in rows}):
                    state.refresh();status=state.status(NOW)
                self.assertFalse(status['stale'])
                self.assertIsNone(status['error'])
                self.assertIsNotNone(status['current'])
                self.assertEqual(status['price_day_complete'],complete)
                self.assertEqual(status['price_coverage_end'],rows[-1]['end'].astimezone(UTC).isoformat())

    def test_solar_request_uses_exact_utc_quarters_across_clock_change(self):
        from controller.service import DEFAULT
        for day in [date(2026,3,29),DAY]:
            rows=prices(day)
            stamps=[int((r['start'].astimezone(UTC)+timedelta(minutes=m)).timestamp()) for r in rows for m in (0,15)]
            with patch('controller.service.direct_session') as session:
                session.return_value.get.return_value.json.return_value={'minutely_15':{'time':stamps,'shortwave_radiation':[0]*len(stamps)}}
                result=fetch_radiation(DEFAULT,day,rows)
                params=session.return_value.get.call_args.kwargs['params']
                self.assertEqual(params['timezone'],'UTC')
                self.assertEqual(params['start_minutely_15'],rows[0]['start'].astimezone(UTC).strftime('%Y-%m-%dT%H:%M'))
                self.assertEqual(params['end_minutely_15'],(rows[-1]['end'].astimezone(UTC)-timedelta(minutes=15)).strftime('%Y-%m-%dT%H:%M'))
                self.assertNotIn('start_date',params)
                self.assertEqual(len(result),len(rows))

    def test_refresh_distinguishes_configuration_price_and_solar_failures(self):
        with tempfile.TemporaryDirectory() as directory:
            state=State(Path(directory)/'policy.json');state.refresh()
            self.assertEqual(state.status()['error_stage'],'configuration')
            self.assertIn('No Agile tariff',state.status()['error'])
            doc=state.document();doc['policy'].update(product='AGILE-EXAMPLE',tariff='E-1R-AGILE-EXAMPLE-G');state.update(doc)
            with patch('controller.service.fetch_controller_prices',side_effect=TimeoutError('private details')):
                state.refresh()
            self.assertEqual(state.status()['error_stage'],'agile_prices')
            self.assertNotIn('private details',state.status()['error'])
            with patch('controller.service.fetch_controller_prices',return_value=prices(DAY)),patch('controller.service.fetch_radiation',side_effect=TimeoutError('private site')):
                state.refresh()
            self.assertEqual(state.status()['error_stage'],'solar_forecast')
            self.assertNotIn('private site',state.status()['error'])
            self.assertFalse(state.status()['price_requests_heat'])

if __name__=='__main__':unittest.main()
