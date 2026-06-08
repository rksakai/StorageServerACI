FROM python:3.12-slim
# Cria usuário não-root por segurança
RUN groupadd -r appuser && useradd -r -g appuser appuser
WORKDIR /app
# Instala dependências primeiro (cache de layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# Copia código da aplicação
COPY app/ .
# Permissões
RUN chown -R appuser:appuser /app
USER appuser
EXPOSE 8080
# Gunicorn com 4 workers e timeout estendido para uploads grandes
CMD ["gunicorn", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "4", \
     "--timeout", "600", \
     "--max-requests", "500", \
     "--max-requests-jitter", "50", \
     "app:app"]