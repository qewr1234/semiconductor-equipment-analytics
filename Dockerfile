# FlowCool 경보 서비스 이미지.
# 빌드 중에 python -m service.demo 를 실행해 합성 데이터로 데모 모델과 DB를 이미지 안에 만든다
# (joblib 번들은 scikit-learn 버전에 묶이므로 이미지와 같은 환경에서 학습한다).
FROM python:3.11-slim

WORKDIR /app

COPY requirements-service.txt .
RUN pip install --no-cache-dir -r requirements-service.txt

# 서비스에 필요한 모듈만 복사한다 (data/, models/ 등은 .dockerignore로 제외).
COPY phm_data.py make_synthetic.py train.py ./
COPY service ./service

ENV FLOWCOOL_MODEL=models/service_demo.joblib \
    FLOWCOOL_DB=data/service/alarms.db
RUN python -m service.demo

EXPOSE 8000
CMD ["uvicorn", "service.app:app", "--host", "0.0.0.0", "--port", "8000"]
