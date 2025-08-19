FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
ENV OPENAI_API_KEY=your_openai_api_key_here
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
