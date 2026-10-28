FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates tzdata && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY homely.py heating_boost.py ./
COPY controller/service.py controller/heating.py controller/slot_policy.py controller/slot_control.py controller/automation.py controller/history.py controller/schedule_target.py controller/boost_target_probe.py ./controller/
# COPY preserves host file modes. Public source extracted under a private NAS
# umask must still be readable by the runtime user; no secrets enter this image.
RUN chmod -R a+rX /app && useradd --uid 10001 --create-home heating && mkdir /data && chown heating:heating /data
USER heating
ENV PYTHONPATH=/app PYTHONUNBUFFERED=1
EXPOSE 8080
CMD ["python", "-m", "controller.service"]
