# FloatNote Design Principles

## Why This Exists

FloatNote는 기능이 많은 앱보다 `조용한 유틸리티`에 가깝다.  
그래서 화면 설계도 일반적인 메모 앱이 아니라 `macOS 위에 잠깐 뜨는 문서 표면` 기준으로 판단해야 한다.

## External References

- Apple Human Interface Guidelines
- Designing for macOS
- Apple UI Design Tips
- WWDC sessions about current macOS/AppKit design and interface writing

## Core Principles

### 1. Content Over Chrome

- 첫 시선은 버튼이 아니라 본문으로 가야 한다.
- 앱 이름, 상태, 설정은 본문을 돕는 수준까지만 보인다.

### 2. One Surface, Not Nested Panels

- 메인 문서를 카드 안에 다시 넣지 않는다.
- 읽기와 쓰기는 같은 표면에서 일어나야 한다.

### 3. Thin Titlebar

- 상단은 macOS 창으로서 필요한 정보만 남긴다.
- 크고 설명적인 툴바는 피한다.

### 4. Keyboard First

- 열기, 닫기, 이동, 크기 조절은 키보드가 주 흐름이다.
- 마우스 액션은 보조 수단이어야 한다.

### 5. Metadata Should Whisper

- `Created`, `Updated`는 항상 보여도 된다.
- 하지만 본문보다 강하면 실패다.

### 6. Utility Copy Should Be Minimal

- 메인 화면에서 기능 설명을 늘어놓지 않는다.
- 필요한 설명은 온보딩과 설정에서만 짧게 한다.

## Applied To FloatNote

### Main Window

- 창은 문서처럼 보여야 한다.
- 본문 폭은 읽기 편한 수준으로 제한한다.
- 타이틀은 작고 조용해야 한다.
- 위치 인디케이터와 이동 버튼만 상단에 남긴다.

### Placeholder

- 빈 노트에서는 행동 유도 한 줄만 보여준다.
- 포커스를 받는 즉시 사라져야 한다.

### Settings

- 별도 Preferences 앱처럼 만들지 않는다.
- 작은 오버레이에서 단축키와 창 크기만 다룬다.

### Markdown Styling

- 과장된 렌더러가 아니라 읽기 보정 역할만 한다.
- 줄간격, 헤딩 크기, 강조 스타일은 입력 안정성을 해치지 않아야 한다.

## Anti-Patterns

- `LAST VIEWED NOTE`, `LIVE MARKDOWN STYLING` 같은 설명 라벨
- 큰 원형 버튼 나열
- 저장 상태를 계속 보여주는 배지
- 본문보다 무거운 상단 바
- 대시보드, 사이드바, 목록 화면

## One-Line Test

FloatNote의 어떤 화면이든 `앱을 보고 있다`보다 `문서를 바로 쓰고 있다`가 먼저 느껴져야 한다.
