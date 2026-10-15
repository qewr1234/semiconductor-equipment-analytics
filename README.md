# 반도체 장비 데이터 프로젝트

| 프로젝트 | 장비 | 과제 | 핵심 결과 |
|---|---|---|---|
| [이온 밀 FlowCool 고장 감지](#이온-밀-flowcool-고장-감지-phm-2018-data-challenge) (PHM 2018) | 이온 밀 식각 장비 | 헬륨 냉각 계통 고장 3종을 1시간 전에 감지 | 오경보 1%에서 무작위 대비 21~30배 감지 |
| [CMP 연마량 예측](cmp2016/README.md) (PHM 2016) | 웨이퍼 연마 장비(CMP) | 웨이퍼별 평균 연마량 예측 + 소모품 마모 해석 | 테스트 MSE 6.29 (대회 상위 5팀 최고 7.07; 대회 후 연구 6.33~6.36 과는 테스트 잡음 안의 차이). 표 파운데이션 모델(TabPFN v2·TabICLv2) 추가로 nested CV 6.61 → 6.31 (Built with PriorLabs-TabPFN). [공장 조건 시뮬레이션](cmp2016/FAB.md): 실시간 VM은 계측 지연 1시간에서 12.9(TabICLv2 멤버로 12.3), 연마 24시간 뒤 확정하는 2단계 VM은 배포 기간 테스트 6.99 / 검증 7.30(같은 기간 대회 방식 6.76 / 6.87) |

## 설비 소프트웨어 기술지원 관점에서 보면

설비 소프트웨어 기술지원(고객 기술지원, 소프트웨어 장애 분석과 원인 규명, 기능 개선, 본사·고객과의 소통) 업무에 비추어 이 저장소가 보여 주는 것입니다.

- **로그 → 원인 → 조치의 추론 구조.** 레시피 단계별 정상 기준(z)을 학습 기간 데이터로만 만들고, 기준 대비 이탈, 같은 고장의 재발 이력(같은 고장의 절반이 하루 안에 재발하고, 고장별 중요 특징 1위가 최근 발생 빈도 `rate_*`), 장비 간 비교(압력 저하 741건 중 298건 = 40%가 03_M02 한 대)를 근거로 경보를 냅니다. 같은 순서를 고객용 문서로 정리한 것이 [`docs/flowcool_alarm_guide.md`](docs/flowcool_alarm_guide.md)입니다.
- **큰 로그를 작은 머신에서.** 학습 로그 8,219만 행(압축 5.4GB, 풀면 34GB)을 메모리 15GB·4코어에서 다루기 위해 tar.gz를 풀지 않고 스트리밍으로 읽어 장비별 Parquet(약 10분, 3.2GB)으로 바꾼 뒤, 행 단위 특징과 가중 표본으로 학습합니다.
- **이벤트 구동 서비스 설계.** CMP 가상 계측을 공장에서 돌아가는 형태로 만든 `VMService`([`cmp2016/FAB.md`](cmp2016/FAB.md))는 계측 도착 `on_metrology()`(값 검증 → 이력 → 추정기 갱신), 연마 종료 `on_wafer()`(예측값·90% 구간·신뢰 플래그), 하루 1회 `maybe_retrain()`(재학습)의 세 이벤트로 돌아갑니다. 예측 1건 3.8 ms, 하루 재학습 2.9초입니다. 같은 조건 과거 계측 중앙값의 3배를 넘는 값은 측정 오류로 버립니다.
- **공장 조건에서 다시 평가.** 대회 점수(테스트 MSE 6.29)는 시험 웨이퍼 앞·뒤의 정답을 함께 쓰는 조건입니다. 처리 순서대로 도착한 계측만 쓰면 계측 지연 1시간에서 12.9이고, 지연을 0으로 줄이면 9.26으로 모델을 바꾸는 것(12.9 → 12.3)보다 효과가 큽니다. 몇 시간 기다려도 되는 용도(로트 판정·SPC)는 24시간 뒤 확정하는 2단계 VM이 6.99 / 7.30으로 대회 방식(6.76 / 6.87)에 가깝습니다.
- **검증 규율과 정직한 한계.** 시간순 분할과 nested CV로만 설정을 고르고, 테스트·검증 정답은 마지막 보고에만 썼습니다. FlowCool 모델은 대회 채점식으로는 전부 NaN 제출과 점수가 같고(76.284), 오경보 1%에서 감지율 21~30%이지만 경보 정밀도(울린 경보 중 실제로 1시간 안에 고장이 따르는 비율)는 고장 1시간 이내 구간 비율 0.07~0.31%(`dashboard/data.json`의 base_rate)로 계산하면 약 2~6%에 그칩니다(근사). 그래서 경보는 인터록이 아니라 점검 권고로 씁니다.
- **설비 물리로 설명하기.** CMP에서는 드레서가 닳을수록 챔버 4의 연마량이 약 11~14% 줄었고, 드레서 교체 전후 비교와 수명 안 기울기로 확인했습니다. 공정 설정(P·V)보다 소모품 상태가 차이를 만든다는 결론을 고객에게 설명할 수 있는 형태로 정리했습니다.
- **소프트웨어로 묶기.** 분석 결과를 현장에서 쓰는 형태로 `service/`(FlowCool 경보 REST API + SQLite 알람 이력 + Dockerfile)와 `assistant/`(문서 기반 알람 대응 도우미)를 두었습니다.
- **본사·고객용 문서.** [`README_EN.md`](README_EN.md)(해외 본사 공유용 영문 요약), [`docs/flowcool_alarm_guide.md`](docs/flowcool_alarm_guide.md)(고객용 경보 대응 메모: 증상 → 확인 순서 → 추정 원인 → 조치 → 에스컬레이션).
- **재현성.** 누수 검사 테스트(컷오프 이후 정답을 바꿔도 이전 예측이 한 자리도 바뀌지 않는지), 결정적 실행, 캐시와 실행 시간 기록(`python -m pytest`).

## AI 사용 고지와 역할

<!-- (이 절은 지원자가 실제 관여 내용에 맞게 다듬어 주세요) -->

- 이 저장소의 코드·분석·문서는 AI 코딩 도우미 Claude(Claude Code)와 함께 작성했습니다. 이 문서를 쓰는 시점의 git log 기준으로 커밋 20개 중 19개의 작성자가 Claude입니다.
- 지원자가 한 일: 문제와 목표 설정(두 데이터셋 선택, 대회 채점식을 목표로 삼기, 대시보드, 드레서 마모의 기계공학 관점 분석, 공장 조건에서 다시 평가하라는 요구, 2022~2026년 문헌 확인), 무엇을 남길지 결정(낙관적인 수치 대신 nested CV와 정직한 경보 정밀도 보고, Kaggle 정답 파일 설명 오류 정정), 결과 검토와 수정 요청.
- Claude가 한 일: 코드 작성과 실험 실행, 수치 집계, 문서 초안 작성.
- 수치는 모두 저장소 안의 실행 결과(`dashboard/data.json`, `cmp2016/*.json`)에서 나왔고, 지원자가 모든 내용을 설명할 수 있어야 한다는 기준으로 설계를 단순하게 유지했습니다.

# 이온 밀 FlowCool 고장 감지 (PHM 2018 Data Challenge)

반도체 웨이퍼 식각 장비(Ion Mill Etch; PHM Society 2018 Data Challenge 공개 데이터(대회 주최 측 소속은 Seagate; 장비 공급사는 비공개)) 20대의 4초 간격 센서 로그로, 웨이퍼 냉각용 헬륨 계통(FlowCool)에서 생기는 세 가지 고장이 1시간 안에 일어날지를 예측한 개인 프로젝트입니다.

- 데이터: [PHM Society 2018 Data Challenge](https://phmsociety.org/conference/annual-conference-of-the-phm-society/annual-conference-of-the-prognostics-and-health-management-society-2018-b/phm-data-challenge-6/) (압축 5.4GB, 풀면 34GB, 학습 8,219만 행)
- 결과 대시보드: `dashboard/index.html` (한 파일짜리 HTML, 브라우저로 열면 됩니다)
- 경보 대응 가이드(고객·현장용 기술 메모): [`docs/flowcool_alarm_guide.md`](docs/flowcool_alarm_guide.md)

## 결과 요약

검증은 장비마다 앞 75% 기간으로 학습하고 뒤 25% 기간으로 했습니다. 대회 테스트 데이터가 같은 장비의 바로 다음 기간이라 같은 방식으로 나눴습니다.

| 고장 | AUC | 감지율 (오경보 1%) | 무작위 대비 |
|---|---|---|---|
| FlowCool Pressure Dropped Below Limit (압력 저하) | 0.850 | 21.4% | 21배 |
| Flowcool Pressure Too High Check Flowcool Pump (압력 과다) | 0.822 | 29.9% | 30배 |
| Flowcool leak (누설) | 0.881 | 30.1% | 30배 |

감지율은 정상 구간의 1%에서만 경보가 울리도록 기준을 잡았을 때 고장 1시간 이내 구간을 잡아낸 비율입니다. 무작위로 경보를 울리면 1%입니다.

### 대회 채점식에 대해

대회 최종 점수는 원래 점수(S1)와 2차 점수(S2)의 평균이었습니다(2018 PHM 학회 Data Challenge 논문 #589, #590, #591의 채점표). 2차 점수는 숫자로 답한 TTF의 오차를 제곱으로 벌하고, 정답이 있는데 NaN으로 답하면 20점만 벌합니다. 그래서 오차를 14초 안으로 보장하지 못하면 NaN이 항상 유리합니다. 기대 벌점을 최소화하는 결정 규칙은 모든 구간에서 NaN을 골랐고, 검증 점수는 전부 NaN 제출과 같습니다(최종 76.284). 대회 순위(1위 0.762)는 공개되지 않은 별도 검증 세트와 정규화로 매겨져 직접 비교할 수 없습니다.

## 방법

1. **변환** (`convert_rows.py`): 원본 tar.gz를 압축 해제 없이 스트리밍으로 읽어 장비별 parquet으로 저장합니다.
2. **행 단위 특징** (`row_features.py`): 과거 데이터만 쓰는 206개 특징을 만듭니다.
   - 1분~하루 롤링 통계 (FlowCool 압력·유량, 챔버 압력, 빔·억제 전류)
   - 레시피 단계별 정상값 대비 z (학습 기간 데이터로만 기준을 만듦)
   - 정상 구간에서 학습한 압력→유량 곡선의 잔차 (Hitachi 팀 논문 #590의 아이디어)
   - 압력·유량 이탈, 장비 정지 이후 경과 시간과 최근 발생 횟수 (같은 고장의 절반이 하루 안에 재발)
3. **모델** (`train_rows.py`): 남은 시간을 13개 구간으로 나눠 LightGBM 다중 분류로 확률을 예측합니다. 고장 3시간 이내 행은 2행마다 하나, 나머지는 2%만 뽑고 가중치로 보정합니다. 예측 확률과 채점식으로 기대 벌점이 가장 작은 답(숫자 또는 NaN)을 고릅니다.
4. **대시보드** (`build_dashboard.py`): 검증 결과를 요약해 `dashboard/index.html`을 만듭니다.

## 실행

```bash
pip install -r requirements.txt

# 1) 원본 데이터 받기 (대회 페이지의 Google Drive 링크, 5.4GB)
pip install gdown
gdown 15Jx9Scq9FqpIGn8jbAQB_lcHSXvIoPzb -O data/raw/phm_data_challenge_2018.tar.gz

# 2) 행 단위 parquet으로 변환 (약 10분, 3.2GB)
python convert_rows.py --archive data/raw/phm_data_challenge_2018.tar.gz --out data/rows

# 3) 학습 표본 만들기 (약 20분) -> 학습과 검증 (약 30분)
python train_rows.py sample --rows-dir data/rows --out data/samples/rows_v3.parquet
python train_rows.py fit --sample data/samples/rows_v3.parquet --save-proba data/val_proba_v5.npz

# 4) 대시보드 생성
python build_dashboard.py --sample data/samples/rows_v3.parquet --proba data/val_proba_v5.npz

# 5) 경보 서비스와 알람 대응 도우미 (선택; 원본 데이터 없이도 동작)
python -m service.demo                 # 합성 데이터로 경보 API 데모 (SQLite 알람 이력)
python -m uvicorn service.app:app      # FlowCool 경보 REST API
python -m assistant.build_index        # 문서 인덱스 만들기 (처음 한 번 임베딩 모델 약 470MB 내려받음)
python -m assistant.ask '질문'         # 알람 대응 RAG 도우미
```

메모리 15GB, 4코어 환경에서 확인했습니다. 저장소 루트의 `Dockerfile`(의존성은 `requirements-service.txt`)로 경보 API 컨테이너 이미지를 만들 수 있습니다(개발 환경에 Docker 데몬이 없어 빌드는 확인하지 못했습니다).

## 파일 구성

```
convert_rows.py        원본 tar.gz -> 장비별 행 단위 parquet
row_features.py        행 단위 특징 (롤링 통계, 단계별 z, 압력->유량 잔차, 이벤트 경과 시간)
train_rows.py          표본 생성, LightGBM 학습, 채점식 기반 결정 규칙, 검증 점수
build_dashboard.py     대시보드 수치 요약과 HTML 생성
dashboard/             대시보드 템플릿, 요약 수치(data.json), 결과 페이지(index.html)
phm_data.py            공통 상수, 대회 채점식(S1, S2, 최종)
docs/flowcool_alarm_guide.md   FlowCool 경보 대응 가이드 (고객·현장용 기술 메모)
README_EN.md           영문 요약 (해외 본사 공유용)
service/               FlowCool 경보 REST API(FastAPI) + SQLite 알람 이력 (python -m service.demo 로 합성 데이터 데모; python -m uvicorn service.app:app; Dockerfile은 저장소 루트)
assistant/             알람 대응 RAG 도우미 (python -m assistant.build_index; python -m assistant.ask '질문')
Dockerfile, requirements-service.txt   경보 API 컨테이너 이미지 (service/ 만 담음)
cmp2016/               CMP 연마량 예측 (PHM 2016): README.md, FAB.md(공장 조건 시뮬레이션), fab_references.md

# 처음에 만든 30분 윈도우 베이스라인 (비교용)
prepare_features.py    원본 -> 30분 윈도우 특징
train.py, predict.py   윈도우 특징으로 TTF 회귀
make_synthetic.py      실제 데이터 없이 파이프라인을 시험하는 합성 데이터
tests/                 pytest 테스트 (각 모듈의 누수·인과성 검사 포함)
```

## 테스트

```bash
pip install pytest
python -m pytest
```

FlowCool 행 특징이 미래 정보를 쓰지 않는지(`tests/test_rows.py`), CMP 특징의 정답 누수(`tests/test_cmp.py`), FAB 시뮬레이션에서 컷오프 이후 정답을 바꿔도 이전 예측이 바뀌지 않는지(`tests/test_fab.py`, `tests/test_fab_phase2.py`)를 확인합니다. `service/`·`assistant/`의 테스트도 같은 명령으로 함께 돕니다.
