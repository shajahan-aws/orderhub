# Multi-stage optimized Dockerfile running as non-root user 'orderhub'
FROM python:3.12-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim

# Create non-root user orderhub
RUN groupadd -g 10001 orderhub && \
    useradd -u 10001 -g orderhub -s /bin/sh -m orderhub

WORKDIR /app

# Copy dependencies and application source
COPY --from=builder /root/.local /home/orderhub/.local
COPY --chown=orderhub:orderhub app/ /app/app/

ENV PATH=/home/orderhub/.local/bin:$PATH \
    PYTHONPATH=/app \
    APP_VERSION=1.0.0 \
    PORT=8080

USER orderhub

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')" || exit 1

CMD ["python", "app/app.py"]