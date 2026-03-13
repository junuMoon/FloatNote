# FloatNote

FloatNote는 전역 단축키로 바로 띄워 쓰는 네이티브 macOS 플로팅 노트 앱입니다. 현재 구현은 `Swift + SwiftUI + AppKit + NSTextView` 기준으로 정리되어 있습니다.

## 현재 범위

- 플로팅 macOS 창
- 기본 전역 핫키 `Control + A`
- 이전/다음 노트 이동 단축키
- 생성 순서 기반 노트 이동과 마지막 노트에서 새 노트 생성
- 실시간 마크다운 스타일링
- `Cmd +`, `Cmd -`, `Cmd 0` 본문 글자 크기 조절
- 하단 `Created / Updated`
- 설정 오버레이와 단축키 변경
- `Application Support` JSON 저장

## 레포 구조

- `FloatNote/`: 앱 소스
- `project.yml`: XcodeGen 정의
- `FloatNote.xcodeproj`: 생성된 Xcode 프로젝트
- `scripts/install-to-applications.sh`: 빌드 후 설치/재등록 스크립트
- `PRODUCT_PLAN.md`: 제품 범위와 동작 규칙
- `DESIGN_PRINCIPLES.md`: 시각 원칙과 macOS 유틸리티 앱 기준

## 실행

프로젝트 열기:

```bash
cd /Users/fran/Workspace/FloatNote
open FloatNote.xcodeproj
```

빌드:

```bash
cd /Users/fran/Workspace/FloatNote
xcodebuild -project FloatNote.xcodeproj -scheme FloatNote -configuration Debug build
```

`project.yml`을 바꿨을 때만:

```bash
cd /Users/fran/Workspace/FloatNote
xcodegen generate
```

빌드가 성공하면 설치본이 자동으로 갱신됩니다. 우선 `~/Applications`를 시도하고, 이 환경처럼 쓰기 불가면 `/Users/fran/Workspace/Applications/FloatNote.app`에 설치한 뒤 LaunchServices와 Spotlight를 다시 등록합니다.

## 문서

- [PRODUCT_PLAN.md](/Users/fran/Workspace/FloatNote/PRODUCT_PLAN.md)
- [DESIGN_PRINCIPLES.md](/Users/fran/Workspace/FloatNote/DESIGN_PRINCIPLES.md)
