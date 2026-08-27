# ROHD 프로젝트 템플릿

[ROHD](https://github.com/intel/rohd) 설계 프로젝트의 출발점입니다. 디렉터리 구분과 각
폴더의 규칙, ROHD의 빈 곳을 메우는 로컬 패치, 그리고 시간을 들여야 알게 되는 함정들을
담고 있습니다.

동작하는 예제 설계(카운터)가 하나 들어 있습니다. 자기 설계로 갈아치우는 것을 전제로 합니다.
뼈대만 필요하면 세 파일을 지우세요 — 아무도 이들을 참조하지 않습니다:

```bash
rm lib/counter.dart bin/generate_rtl.dart test/counter_test.dart
```

`packages/rohd_patches/`는 지우지 마세요. `pubspec.yaml`의 워크스페이스 멤버라 의존성
해석이 실패합니다. 개별 패치는 상류 이슈가 닫히면 파일 단위로 지울 수 있습니다 — 아래
"ROHD 로컬 패치" 참고.

## 시작하기

**dev container를 전제로 합니다.** Dart 버전이 고정돼 있고, 파형과 SystemVerilog를 보는
확장이 함께 설치됩니다.

1. VS Code로 폴더를 열고 **Reopen in Container**
2. 끝입니다. `dart pub get`은 컨테이너를 만들 때 이미 돌았습니다 — dart feature의
   `updateContentCommand`가 에디터가 붙기 전에 처리합니다

```bash
dart run bin/generate_rtl.dart          # build/ 에 RTL 을 씁니다
dart test                         # 테스트벤치를 돌립니다
dart test packages/rohd_patches   # 패치 쪽 테스트 (루트 `dart test` 로는 안 돕니다)
```

VS Code 없이 CLI로:

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . dart test
```

CLI는 **확장을 설치하지 않고** VS Code 설정도 읽지 않습니다. 파형을 보려면 VS Code로
여세요.

### 컨테이너가 주는 것

| | |
|---|---|
| Dart | `dartVersion` 옵션으로 고정 — `pubspec.yaml`의 `sdk: ^3.12.2`를 만족해야 합니다 |
| `lramseyer.vaporview` | `build/waves/*.vcd`를 에디터에서 바로 봅니다 |
| `mshr-h.veriloghdl` | 생성된 `build/*.sv` 문법 강조 |
| 셸 | zsh + prezto, fzf 연동 (`^R` 히스토리 검색) |
| CLI 도구 | gh, fzf, ripgrep, fd, bat, lsd, tig, tldr, xxd, file |

### prezto 빼기

zsh를 안 쓰신다면 `.devcontainer/devcontainer.json`의 `features`에서 prezto 항목을
지우면 됩니다. 세 줄입니다:

```jsonc
"ghcr.io/congealer/devcon-features/prezto:1": {
    "extraZshrc": "(( $+commands[fzf] )) && source <(fzf --zsh)"
},
```

**그냥 지우면 fzf의 `^R`도 같이 사라집니다.** fzf 바이너리는 별도 feature라 남지만,
셸 연동이 위의 `extraZshrc`에 얹혀 있기 때문입니다. 그리고 로그인 셸이 bash로
돌아갑니다 — zsh를 로그인 셸로 만드는 것도 prezto가 하는 일입니다.

fzf 연동을 유지하려면 bash 쪽으로 옮기세요:

```jsonc
"postCreateCommand": "echo 'eval \"$(fzf --bash)\"' >> ~/.bashrc"
```

prezto가 싫은 게 아니라 **프로젝트가 강제하는 게 싫은 것**이라면, 템플릿에서 빼고
본인 VS Code 설정에 두는 방법도 있습니다. 그러면 모든 dev container에 붙습니다:

```jsonc
"dev.containers.defaultFeatures": {
    "ghcr.io/congealer/devcon-features/prezto:1": {}
}
```

### Icarus Verilog 켜기

`SimCompare.iverilogVector`로 생성된 SystemVerilog를 실제 Verilog 시뮬레이터와 교차
검증할 때만 필요합니다. 기본은 꺼져 있습니다. `.devcontainer/devcontainer.json`의
`apt-packages` 목록에 `"iverilog"`를 추가하고 컨테이너를 다시 빌드하세요.

### 호스트에서도 돌린다면

`.dart_tool/package_config.json`이 **절대 경로**를 담습니다. 워크스페이스를 호스트와
컨테이너가 공유하므로, 한쪽에서 작업한 뒤 다른 쪽에서 처음 실행하면 이렇게 깨집니다:

```
Error when reading '/home/vscode/.pub-cache/.../rohd.dart': No such file or directory
```

복구는 `dart pub get` 한 번입니다. 호스트 → 컨테이너 방향은 컨테이너를 **새로 만들 때**
자동으로 처리되지만, **재시작만** 하는 경우는 처리되지 않습니다.

## 디렉터리 구성

ROHD의 패키지들(`rohd`, `rohd-hcl`, `rohd-vf`)은 전부 라이브러리라 `bin/`이 없습니다. 그래서
*설계* 프로젝트를 어떻게 나눌지에 대한 정해진 관례가 없습니다. 이 템플릿이 쓰는 구분은
이렇습니다:

| 디렉터리 | 담는 것 | 규칙 |
|---|---|---|
| `lib/` | `Module` 서브클래스와 재사용 헬퍼 | 설계만 — `main()`도 자극도 없음 |
| `bin/` | 진입점 | **합성만.** 시뮬레이션하지 않음 |
| `test/` | 테스트벤치와 검사 | **DUT를 구동하는 건 전부 여기** |
| `packages/` | 별도 패키지 | 현재는 `rohd_patches` 하나 |
| `build/` | 생성된 산출물 | gitignore 대상. 여기 있는 건 소스가 아님 |

가르는 기준은 **누가 DUT를 구동하는가**입니다. `test/`만 구동합니다. 이 선을 지키면 자극이
정확히 한 곳에만 정의되고, 파형도 데모용으로 따로 쓴 자극이 아니라 테스트에서 나옵니다.

`build/`는 Dart 관례입니다 — ROHD의 `.pubignore`가 이걸 "빌드 출력의 관례적 디렉터리"라고
부릅니다.

---

## `lib/` — 설계

`Module`을 상속한 클래스만 둡니다. 생성자에서 포트를 선언하고 로직을 기술합니다.

```dart
import 'package:rohd/rohd.dart';
import 'package:rohd_patches/rohd_inline.dart';   // `.inl` 을 쓸 때만

class MyDesign extends Module {
  /// 현재 출력.
  Logic get result => output('result');

  MyDesign(Logic a, Logic b, Logic clk, {super.name = 'my_design'}) {
    // 포트는 생성자에서 등록합니다. 모듈 로직은 등록된 입력을 소비하고 등록된
    // 출력으로 내보내야 합니다.
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    clk = addInput('clk', clk);

    final result = addOutput('result', width: a.width);

    // `Sequential` 은 SystemVerilog 의 always_ff 에 해당합니다.
    Sequential(clk, [
      // `<` 는 조건부 대입입니다. `=` 도 `<=` 도 아닙니다.
      result < a.inl + b,
    ]);
  }
}
```

`main()`도, `Simulator` 호출도, 자극도 여기 두지 마세요. 그러면 이 파일이 `bin/`과 `test/`
양쪽에서 그대로 재사용됩니다.

## `bin/` — RTL 생성

`main()`에는 **합성만** 넣습니다. 빌드하고, SystemVerilog를 뽑고, 파일로 씁니다.

```dart
import 'package:rohd/rohd.dart';
import 'package:rohd_patches/rohd_synth.dart';    // writeSynthFile 은 확장 메서드입니다

Future<void> main() async {
  final dut = MyDesign(Logic(name: 'a'), Logic(name: 'b'),
      SimpleClockGenerator(10).clk);

  // 합성 전에 반드시 빌드해야 합니다.
  await dut.build();

  final file = dut.writeSynthFile('build/my_design.sv', header: _header);
  print('Wrote ${file.path}');
}
```

**시뮬레이션하지 마세요.** `Simulator.run()`이 여기 들어가는 순간 자극이 두 곳에 생기고,
둘이 갈라지기 시작합니다. 동작을 보고 싶으면 테스트를 돌리고 파형을 보세요.

출력은 **재현 가능**합니다 — 다시 돌려도 바이트 단위로 같은 파일이 나오므로 생성된 RTL을
diff하거나 커밋할 수 있습니다. ROHD 기본 `generateSynth()`는 생성 시각이 박힌 헤더를
하드코딩해서 이게 안 됩니다. `writeSynthFile`이 그걸 대체합니다 (아래 "ROHD 로컬 패치").

## `test/` — 테스트벤치

`main()`에 테스트를 정의합니다. 파일마다 `<이름>_test.dart`.

```dart
void main() {
  setUp(Simulator.reset);
  tearDown(Simulator.reset);

  test('리셋이 출력을 0 으로 잡는다', () async {
    await MyBench.run(name: 'reset', (b) async {
      await b.reset(duration: 4);
      expect(b.result, 0);
    });
  });
}
```

`setUp`/`tearDown`에 `Simulator.reset`을 **tear-off로** 넘기는 게 중요합니다. `reset()`은
`Future`를 반환하는데, 클로저로 감싸서 `setUp(() { Simulator.reset(); ... })`처럼 쓰면 그
Future가 버려져 다음 테스트가 리셋이 끝나기 전에 시작할 수 있습니다. tear-off는 Future를
그대로 반환하므로 테스트 프레임워크가 기다려줍니다.

### 테스트벤치 하네스

자극은 **테스트의 async 흐름 안에** 두고, `Simulator.run()` 쪽을 `unawaited`로 돌립니다:

```dart
Simulator.setMaxSimTime(_maxSimTime);
unawaited(Simulator.run());

await sequence(b);          // 실패하면 그대로 테스트 실패

await Simulator.endSimulation();
```

반대로 하면 — 자극을 `unawaited` 클로저에 넣고 시뮬레이터를 `await`하면 — 실패한 `expect`가
아무도 붙잡지 않는 Future 안에서 터집니다. 그걸 수습하려면 예외를 통째로 잡아 두었다가
시뮬레이터가 멈춘 뒤 다시 던지는 장치가 필요해집니다. ROHD 자체 테스트도 자극을 줄 때는
이 형태를 씁니다.

`setMaxSimTime`은 폭주 방지입니다. 클럭 생성기가 이벤트를 무한히 만들어내므로, 상한이 없으면
테스트 프레임워크가 타임아웃으로 포기한 뒤에도 시뮬레이터가 계속 돕니다.

### 트랜잭션 수준으로 쓰기

메서드 하나가 트랜잭션 하나에 대응하게 하면, 손으로 계산한 타임스탬프가 사라집니다:

```dart
await b.reset(duration: 2, settle: 1);
await b.count(duration: 6, stall: [1, 2, 4]);
expect(b.val, 3);
```

명명된 인자가 UVM 시퀀스 아이템의 필드 역할을 하되 클래스 계층은 없습니다. 매직
타임스탬프가 없으므로 클럭 주기를 바꿔도 테스트는 그대로 삽니다.

자극은 **negedge**에서 구동하세요. 그래야 그 값을 샘플링하는 posedge 동안 값이 안정적입니다.
posedge에서 구동하면 `Sequential`이 일부러 `X`를 냅니다 (아래 "알아둘 것").

### 파형

기본은 꺼져 있습니다. `WAVES`를 설정하면 `build/waves/` 아래에 테스트당 `.vcd` 하나가
생깁니다:

```bash
WAVES=1 dart test
```

플래그가 아니라 환경 변수인 이유는 `dart test`에 테스트 코드로 값을 넘길 수단이 없기
때문입니다 — `--define`은 거부되고, `dart_test.yaml`은 러너 자체만 설정합니다.

기존 테스트 시퀀스를 재사용하므로 파형 전용 자극은 없습니다.

## `build/` — 산출물

종류마다 하위 디렉터리를 따로 둬서, 글롭 없이 원하는 것만 지울 수 있습니다:

```
build/
├── my_design.sv      # RTL
└── waves/            # 테스트당 .vcd 하나
```

Dart에는 `clean` 명령이 없습니다 — `dart pub cache clean`은 전역 패키지 캐시만 지웁니다 —
그래서 그냥 `rm`으로 지웁니다:

```bash
rm -rf build/waves   # 파형만
rm -rf build         # 산출물 전부
rm -rf .dart_tool    # Dart 빌드 캐시까지 (다음 실행이 느려집니다)
```

---

## `packages/rohd_patches` — ROHD 로컬 패치

ROHD에 아직 없는 기능을 메우는 패치 모음입니다. **파일 하나 = 이슈 하나**라, 상류가 해당
문제를 해결하면 그 파일만 지우면 됩니다. 배럴 파일을 만들지 않는 이유도 이것입니다 — 묶으면
이슈 하나가 닫혔을 때 나머지가 딸려 나옵니다.

의도적으로 **격리**돼 있습니다. 모듈의 포트나 공개 인터페이스는 아무것도 바뀌지 않으므로
상위 모듈이 이걸 import할 일이 없습니다.

### 왜 `lib/`가 아니라 별도 패키지인가

나중에 별도 리포로 들어내는 **비용을 미리 낮춰두기 위해서**입니다. 패키지 경계가 있으면
import가 `package:rohd_patches/...`로 고정되므로, 프로젝트 이름을 바꾸든 패치를 다른 리포로
옮기든 **소스는 한 줄도 안 바뀝니다.** 바뀌는 건 `pubspec.yaml` 몇 줄뿐입니다.

평범한 `path:` 의존성이 아니라 **워크스페이스 멤버**인 것도 이유가 있습니다. 워크스페이스는
`package_config.json`을 루트에만 만들지만, `path:` 의존성은 서브패키지마다 `.dart_tool`을
만들어 아래 절대 경로 문제를 두 배로 겪게 합니다.

```yaml
# 루트 pubspec.yaml
workspace:
  - packages/rohd_patches
dependencies:
  rohd_patches: any        # 선언이 없으면 depend_on_referenced_packages 가 뜹니다
```

`any`인 이유는 워크스페이스 멤버의 버전이 로컬 소스에서 결정되기 때문입니다. 못박으면 멤버
버전을 올릴 때마다 두 군데를 고쳐야 합니다.

### `rohd_inline.dart` — 인라인되는 산술

ROHD의 `+`는 출력이 **둘**(합과 캐리)인 `Add` 모듈을 만듭니다. SystemVerilog 합성기는 출력이
하나인 모듈만 인라인하므로, 덧셈마다 `always_ff` 블록 **밖으로** `assign {carry, sum} = ...;`
가 튀어나오고 아무도 안 읽는 캐리 와이어가 남습니다. ROHD의 다른 산술 모듈은 전부 출력이
하나라 잘 인라인되는데, `Add`만
[intel/rohd#478](https://github.com/intel/rohd/pull/478)에서 순전히 SystemVerilog lint 경고를
피하려고 예외가 됐습니다.

```dart
result < a.inl + 1    // always_ff 안에 머무름, 캐리 와이어 없음

a.add(b)              // `+` 대체: 같은 폭, 같은 랩어라운드
a.addWide(b)          // max(wa,wb)+1 폭, 캐리가 최상위 비트
a.mulWide(b)          // wa+wb 폭. ROHD의 `*` 는 상위 절반을 버립니다
```

`.inl`은 신호를 감싸서 `+`가 인라인 가능한 가산기로 가게 합니다. 래퍼는 이름 없는 병합 가능
신호라 생성된 RTL에 흔적을 남기지 않습니다.

### `rohd_synth.dart` — 헤더 제어와 파일 출력

```dart
dut.generateSynthWith(header: '...')     // ROHD 고정 헤더를 대체
dut.writeSynthFile('build/design.sv')    // 파일 하나
dut.writeSynthFiles('build')             // 모듈당 파일 하나
```

두 가지를 메웁니다. 끌 수 없는 타임스탬프 헤더
([#579](https://github.com/intel/rohd/issues/579), open)와, 결과를 파일로 저장할 방법이 아예
없는 것([#239](https://github.com/intel/rohd/issues/239), 2022년부터 open)입니다.

---

## ROHD를 쓰며 알아둘 것

- **폭이 정확히 맞아야 합니다.** 대입과 모든 이항 연산자가 **양방향**으로 폭 불일치를
  거부합니다 — 좁은 값을 넓은 신호에 넣는 것도 오류입니다. `Logic`은 부호 정보를 갖지 않아서
  (`LogicValue`는 부호 없음으로 문서화돼 있습니다) ROHD가 `zeroExtend`와 `signExtend` 중
  무엇일지 추측하지 않습니다. `zeroExtend`, `signExtend`, `getRange`/`slice`를 명시적으로
  쓰세요.
- **`Sequential`은 의도적으로 `X`를 냅니다.** 트리거 입력과 비트리거 입력이 같은 타임스텝에
  바뀔 때입니다. 실제 하드웨어에서 어느 값이 잡힐지 예측할 수 없으니 경쟁 조건으로 보는
  것입니다. 리셋 해제 직후 시뮬레이션 전체가 `X`가 되면 자극이 클럭 엣지에 걸쳐 들어가는지
  확인하세요.
- **`SimCompare`/`Vector`** (`package:rohd/src/utilities/simcompare.dart`)는 벡터 표를 ROHD
  시뮬레이터와 Icarus Verilog 양쪽에 돌려 비교합니다. export되지도 문서화되지도 않았지만
  (export하는 것이 [#134](https://github.com/intel/rohd/issues/134), 2022년부터 open) ROHD
  자체 테스트는 이걸로 쓰여 있습니다. 벡터가 한 사이클 뒤처져 읽힌다는 점에 주의하세요 —
  어떤 행의 기대 출력은 **이전** 행의 효과를 나타냅니다.
