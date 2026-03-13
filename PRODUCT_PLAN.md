# FloatNote Product Plan

## Product Definition

FloatNote는 `관리 UI`보다 `즉시 입력`을 우선하는 플로팅 문서다.  
핵심 가치는 메모를 모으는 것이 아니라, 현재 작업을 끊지 않고 한 줄을 붙잡는 데 있다.

## Product Rules

- 전역 단축키로 어디서든 창을 열고 닫는다.
- 앱을 열면 `마지막으로 본 노트`가 열린다.
- 커서는 바로 본문에 있어야 한다.
- 노트 순서는 `생성 순서`다.
- 왼쪽은 더 오래된 노트, 오른쪽은 더 새로운 노트다.
- 마지막 노트에서 오른쪽으로 가면 새 노트를 만든다.
- 하단에는 `Created`, `Updated`를 항상 표시한다.
- 화면은 문서처럼 보여야 하고, 툴바 앱처럼 보이면 안 된다.

## Current MVP

### Implemented

- 네이티브 macOS 창
- 전역 토글 핫키
- 이전/다음 노트 이동
- 새 노트 생성
- 자동 저장과 마지막 노트 복귀
- 실시간 마크다운 스타일링
- 설정 오버레이
- 창 크기 설정
- 본문 글자 크기 조절: `Cmd +`, `Cmd -`, `Cmd 0`

### Intentionally Out Of Scope

- 태그, 폴더, 목록 화면
- 동기화
- 파일 export
- 별도 미리보기 패널
- 복잡한 문서 관리 기능

## Interaction Model

### Open

1. 사용자가 전역 단축키를 누른다.
2. FloatNote가 현재 작업 위에 뜬다.
3. 마지막으로 보던 노트가 열린다.
4. 커서는 본문에 있다.

### Move

1. 이전/다음 단축키를 누른다.
2. 같은 창 안에서 인접 노트로 이동한다.
3. 첫 노트의 왼쪽은 no-op다.
4. 마지막 노트의 오른쪽은 새 노트 생성이다.

### Close

1. `Escape` 또는 전역 단축키를 다시 누른다.
2. 현재 상태를 저장한다.
3. 창이 사라지고 원래 작업으로 복귀한다.

## Design Constraints

- 본문이 화면의 주인공이어야 한다.
- 설명 라벨을 메인 화면에 올리지 않는다.
- 상단 크롬은 얇고 조용해야 한다.
- 본문을 또 다른 카드 안에 넣지 않는다.
- 메타데이터는 보이되 속삭이는 수준이어야 한다.

## Storage

- 저장 위치: `~/Library/Application Support/FloatNote/state.json`
- 현재 방식: 로컬 JSON
- 저장 전략:
  - 입력 중 debounce 저장
  - 노트 이동 시 즉시 저장
  - 창 닫을 때 즉시 저장

## Repo Notes

- 루트는 앱 실행과 유지보수에 필요한 파일만 남긴다.
- 오래된 시안과 중복 문서는 유지하지 않는다.
- 현재 소스 오브 트루스는 `README.md`, `PRODUCT_PLAN.md`, `DESIGN_PRINCIPLES.md`다.

## Next Candidate Work

- 로그인 시 자동 실행
- 노트별 마지막 커서 위치 복구
- 체크리스트 문법 보강
- Markdown export 또는 SQLite 전환 검토
