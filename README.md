# Team-MINO-iOS
안녕하세요민호야잘하자iOS팀레포인데요일단임시레포를팟어요많은관심부탁드립니다

## > *「諦めるな…！俺たちのコードは、まだ終わっていない！」*

<div align="center">
    <img src="https://github.com/user-attachments/assets/d052ad90-0567-40da-8f5e-915baeb6a028" width="1200" height="800" alt="Video" />
  </a>
</div> 



## 🎵✨ ↓↓↓ チームMINO iOS 公式テーマソング ↓↓↓ ✨🎵

> *「この曲を聴けば…力が湧いてくる気がする。不思議だろう？」* 🔥💫
<div align="center">
  <a href="https://www.youtube.com/watch?v=OzGVz1ClxIc">
    <img src="https://img.youtube.com/vi/OzGVz1ClxIc/maxresdefault.jpg" width="800" height="476" alt="Video" />
  </a>
</div>

--
## 🏗️ 모듈 구조 (Clean Architecture + DDD, SPM)

Tuist를 걷어내고 레이어 단위 로컬 SPM 패키지로 구성한다. 의존성은 바깥에서 안쪽으로만 향한다 (`Feature → Domain ← Data`).

```
Team-MINO-iOS/
├── App/                      # 컴포지션 루트 (얇은 .xcodeproj). 구체 타입은 여기서만 조립
│   ├── App.xcodeproj
│   └── Sources/              # AppDelegate, SceneDelegate, AppDependencies
└── Packages/                 # 레이어 단위 로컬 SPM 패키지
    ├── Core/                 # 공용 유틸 (의존성 없음)
    ├── Networking/           # HTTPClient, Endpoint, NetworkError  → Core
    ├── Domain/               # Entity, ValueObject, UseCase, Repository protocol  → Core
    ├── Data/                 # Repository 구현, DTO, Mapper  → Domain, Networking
    ├── DesignSystem/         # UIKit 컴포넌트·토큰  → Core
    └── Feature/              # 화면(ViewController)  → Domain, DesignSystem
```

의존성 그래프:

```
App ──▶ Feature ──▶ Domain ──▶ Core
   │       └──────▶ DesignSystem ──▶ Core
   └──▶ Data ──▶ Domain
            └──▶ Networking ──▶ Core
```

- **Domain은 어떤 인프라도 모른다** (Data/Networking/UIKit import 금지)
- **Feature는 Data를 모른다.** Repository 구현은 `App/AppDependencies`에서 주입
- **DTO는 Data 내부에 internal로 닫혀** Domain에 노출되지 않는다 (`toDomain()` 매핑)

### 빌드 / 테스트

```bash
# 앱 (전 레이어 통합 빌드)
open App/App.xcodeproj          # Xcode에서 App 스킴 실행

# 순수 로직 패키지 단위 테스트
cd Packages/Core   && swift test
cd Packages/Domain && swift test
# UIKit/네트워킹 의존 패키지(Networking/Data/DesignSystem/Feature)는
# iOS 시뮬레이터에서 빌드/테스트한다 (macOS 호스트의 swift build 미지원)
```

> `App.xcodeproj`는 xcodegen으로 1회 부트스트랩 생성한 산출물이며, 이후 앱 타깃 설정은 Xcode에서 직접 관리한다.

--
## App Download

<a href="" target="_blank">
  <img src="https://github.com/user-attachments/assets/e7e0253d-26bc-4fd3-9f4d-1ff8c24f00fe" alt="App Store Download" width="150" />
</a>

<p>
  <!-- <a href="https://apps.apple.com/kr/app/%EC%93%B8%EB%9E%98%EB%A7%90%EB%9E%98/id6746895814" target="_blank">앱스토어에서 다운로드</a> -->
</p>

---

## Contributors

<table>
  <tr align="center">
    <td><b>박병호</b></td>
    <td><b>김유빈</b></td>
    <td><b>이지훈</b></td>
  </tr>
  <tr align="center">
    <td>
      <img src="https://github.com/user-attachments/assets/57e92d6b-356c-4acf-9bf5-38f7f2aa573c" width="200" height="400"><br>
      <a href="https://github.com/hoBahk"><i>hoBahk</i></a>
    </td>
    <td>
      <img src="https://github.com/user-attachments/assets/fb7bdad1-d95a-450a-8da8-8c38ada83451" width="200" height="400"><br>
      <a href="https://github.com/dbqls200"><i>dbqls200</i></a>
    </td>
    <td>
      <img src="https://github.com/user-attachments/assets/65ef658f-55e4-46cc-a70b-ae1ad1c49848" width="200" height="400"><br>
      <a href="https://github.com/hooni0918"><i>hooni0918</i></a>
    </td>
  </tr>
</table>

---


<div align="center">
  <a href="https://hits.sh/github.com/mash-up-kr/Team-MINO-iOS/">
    <img src="https://hits.sh/github.com/mash-up-kr/Team-MINO-iOS.svg" alt="Hits">
  </a>
</div>

