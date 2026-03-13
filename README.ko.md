# FloatNote

FloatNote는 이제 `Swift + SwiftUI + AppKit`으로 다시 만든 네이티브 macOS 앱입니다.

구조는 `~/Workspace/Glacier`처럼 루트에 프로젝트 정의를 두는 방식으로 맞췄습니다.

- 루트 `project.yml`
- 루트 `FloatNote.entitlements`
- 루트 `FloatNote.xcodeproj` 생성
- 앱 소스는 `FloatNote/`

## 실행 방법

바로 열기:

```bash
cd /Users/fran/Workspace/FloatNote
open FloatNote.xcodeproj
```

`project.yml`을 바꿨을 때만 다시 생성:

```bash
cd /Users/fran/Workspace/FloatNote
xcodegen generate
```

터미널 빌드:

```bash
xcodebuild -project FloatNote.xcodeproj -scheme FloatNote -configuration Debug build
```

## 현재 구현 범위

- 플로팅 macOS 윈도우
- 기본 전역 핫키 `Control + A`
- 이전 / 다음 기본 단축키 `Control + Shift + Left/Right`
- 헤더, 리스트, 인용, 강조, 링크, 코드블록 기준의 실시간 마크다운 스타일링
- 마지막으로 본 노트 복귀
- 생성 순서 기준 좌우 이동
- 마지막 노트 오른쪽에서 새 노트 생성
- 하단 `Created` / `Updated`
- 온보딩 오버레이
- 설정 오버레이
- Application Support JSON 저장

## 문서

- [PRODUCT_PLAN.md](/Users/fran/Workspace/FloatNote/PRODUCT_PLAN.md)
- [UX_FLOW.md](/Users/fran/Workspace/FloatNote/UX_FLOW.md)
- [WIREFRAMES.md](/Users/fran/Workspace/FloatNote/WIREFRAMES.md)
- [README.md](/Users/fran/Workspace/FloatNote/design/lowfi/README.md)
