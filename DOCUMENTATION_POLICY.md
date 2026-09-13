# Documentation maintenance policy

Agile Price Wheel maintains two documentation surfaces:

1. `README.md` — the comprehensive developer, architecture, setup, dependency, data-flow, caching, build and distribution reference in GitHub.
2. `AgilePriceWheel/DocumentationView.swift` — the user-facing guide shipped inside the iOS application.

## Required rule for future changes

Any change that alters application behaviour must update the relevant documentation **in the same change/commit or pull request**.

This includes changes to:

- user-visible features or controls;
- price-wheel behaviour or calculations;
- tariff discovery or Octopus API integration;
- network behaviour and error handling;
- offline caching, persistence or refresh behaviour;
- server/local data-source indicators;
- privacy or stored information;
- Swift/Xcode/iOS requirements;
- dependencies or frameworks;
- project setup, signing, building or deployment;
- file/module architecture;
- testing or diagnostics procedures.

Before a release, verify that the README describes the current implementation and that the in-app Guide describes the current user-visible behaviour. Documentation-only wording changes do not require a corresponding code change.

## Source of truth

The implementation is authoritative for actual behaviour. `README.md` should explain that implementation comprehensively. `DocumentationView.swift` should explain the parts a user needs while operating the app, including offline behaviour and how to identify whether displayed information is live server data or local cached data.

If implementation and documentation disagree, treat that as a defect and update the documentation and/or implementation together.
