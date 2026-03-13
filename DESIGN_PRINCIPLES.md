# FloatNote 디자인 원칙 메모

## 1. 목적

이 문서는 `유틸성 macOS 프로그램`의 디자인 원칙을 외부 자료 기준으로 정리하고, FloatNote에 어떻게 적용해야 하는지 명확히 하기 위한 메모다.

## 2. 참고한 외부 자료

- Apple Human Interface Guidelines
  - https://developer.apple.com/design/human-interface-guidelines/
- Designing for macOS
  - https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- UI Design Dos and Don'ts
  - https://developer.apple.com/design/tips/
- WWDC25: Get to know the new design system
  - https://developer.apple.com/videos/play/wwdc2025/356/
- WWDC25: Build an AppKit app with the new design
  - https://developer.apple.com/videos/play/wwdc2025/310/
- WWDC22: Writing for interfaces
  - https://developer.apple.com/videos/play/wwdc2022/10037/

## 3. 조사에서 나온 핵심 원칙

### 원칙 1. content over chrome

Apple HIG는 시각 위계를 분명하게 만들고, 인터페이스 요소가 `content beneath them`과의 관계 속에서 작동해야 한다고 본다.  
WWDC25의 새 디자인 시스템 설명도 인터페이스와 콘텐츠의 관계를 다시 정립하는 데 초점을 둔다.

FloatNote 적용:

- 메인 화면에서 가장 먼저 보여야 하는 것은 노트 본문이다.
- 툴바, 배지, 설명 문구가 본문보다 먼저 읽히면 안 된다.

### 원칙 2. bar items are scarce, grouped, and purposeful

WWDC25는 bar가 crowded하게 느껴지면 불필요한 항목을 제거하고, secondary action은 더 보기나 다른 보조 UI로 옮기라고 말한다.  
또 항목은 function과 frequency 기준으로 묶어야 한다.

FloatNote 적용:

- 메인 상단에는 `이전`, `위치`, `다음`, `설정` 정도만 남긴다.
- `저장`, `닫기`, 기술 설명 라벨은 메인 바에서 제거한다.

### 원칙 3. controls stay close to the content they modify

Apple의 UI tips는 controls를 `the content they modify` 가까이에 두라고 한다.  
반대로 콘텐츠와 무관한 전역 액션이 화면을 점령하면 hierarchy가 흐려진다.

FloatNote 적용:

- 화면 전체를 설정형 툴바처럼 만들지 않는다.
- 노트 이동처럼 본문 흐름과 직접 관련 있는 액션만 화면에 남긴다.

### 원칙 4. non-interactive information must not look like a button

WWDC25 AppKit 세션은 non-interactive title이나 status indicator가 glass 위에 올라가면 버튼처럼 보일 수 있으니 피하라고 한다.

FloatNote 적용:

- `SAVED`, `LAST VIEWED NOTE`, `LIVE MARKDOWN STYLING` 같은 상태 문구를 메인 화면에서 버튼처럼 보이게 두지 않는다.
- 상태 텍스트는 조용한 보조 정보여야 한다.

### 원칙 5. large displays should show more content, not more nesting

Designing for macOS는 큰 디스플레이를 활용해 fewer nested levels와 less need for modality를 지향하라고 한다.

FloatNote 적용:

- 본문을 카드 안에 다시 넣는 중첩 구조를 피한다.
- 설정과 온보딩도 가능하면 작은 callout나 popover로 해결한다.

### 원칙 6. words should help people do what they want to do

WWDC22 Writing for interfaces는 단어가 잘 작동하면 눈에 띄지 않지만, 사람들이 하고 싶은 일을 하는 데 핵심이라고 설명한다.  
즉, 문구는 브랜드 과시나 기능 설명보다 행동 지원에 써야 한다.

FloatNote 적용:

- 메인 화면 문구는 최소화한다.
- placeholder나 첫 실행 안내는 `지금 무엇을 하면 되는지`만 짧게 알려준다.

## 4. FloatNote에 대한 파생 원칙

### 파생 원칙 A. 앱이 아니라 문서처럼 보여야 한다

- 창은 유틸리티지만 화면은 문서형이어야 한다.
- 사용자는 제품 UI를 읽기 전에 이미 한 줄을 쓰고 있어야 한다.

### 파생 원칙 B. 메인 화면에는 설명을 올리지 않는다

- 메인 화면에서 기술 상태를 설명하지 않는다.
- 기능은 행동으로 이해되게 하고, 설명은 설정이나 온보딩으로 보낸다.

### 파생 원칙 C. 상단 크롬은 거의 안 보여야 한다

- 상단은 제품 존재를 알리는 정도로만 유지한다.
- 큰 버튼, 굵은 서브타이틀, 둥근 칩 나열은 피한다.

### 파생 원칙 D. 메타데이터는 whisper level이어야 한다

- `Created`, `Updated`는 항상 보여도 된다.
- 다만 본문보다 강조되면 안 된다.

### 파생 원칙 E. mouse UI는 보조다

- 주 흐름은 키보드다.
- 마우스로도 쓸 수 있지만, 마우스용 크롬이 키보드 흐름을 압도하면 안 된다.

## 5. FloatNote에 바로 반영할 결정

### 메인 창

- `Last viewed note`, `Live markdown styling`, `Saved` 같은 라벨 제거
- 본문 카드 제거 또는 최대한 약화
- 본문을 화면의 중심 문서 표면으로 승격
- 상단 액션 수 최소화

### 온보딩

- 짧은 callout
- 세 줄 이하 설명
- 본문 구조를 가리지 않을 것

### 설정

- 작고 단순한 popover 또는 얕은 시트
- 메인 플로우를 끊지 않는 구조

## 6. 한 문장 요약

FloatNote는 `잘 꾸며진 유틸리티 앱`보다 `거의 크롬이 보이지 않는 플로팅 문서`에 가까워야 한다.
