FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tesseract-ocr \
        tesseract-ocr-chi-sim \
        tesseract-ocr-eng \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir pillow pytesseract requests

WORKDIR /app
COPY hermes_image_bridge.py /app/hermes_image_bridge.py

EXPOSE 8765
CMD ["python", "/app/hermes_image_bridge.py"]
