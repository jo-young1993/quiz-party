# 팡팡! QUIZ LIVE — 무료 120인 퀴즈 행사 키트

## 지금 받은 파일
- `index.html` : 진행자/참가자 화면, 입장, 정답, 순위, QR, 화려한 시상식, 웹 오디오 음향
- `schema.sql` : Supabase 데이터베이스 및 보안 RPC (정답은 서버에서 판정)
- `questions-2026.json` : 보내주신 카훗 캡처의 8문제 및 정답 반영 파일
- `assets/question6-fan.png` : 6번 부채 사진
- **원본 캡처 문장을 가능한 한 그대로 옮겼으며, 화면 글씨가 작은 부분은 행사 전 검수 권장**

## 1) 무료 데이터베이스 설정
1. https://supabase.com 에 회원가입하고 New project를 만듭니다.
2. `SQL Editor > New query`에서 `schema.sql` 전체를 붙여넣고 실행합니다.
3. `Authentication > Providers > Anonymous Sign-ins`에서 익명 로그인(Anonymous Sign-ins)을 **ON**으로 설정합니다. 참가자 전용입니다.
4. `Authentication > Users > Add user`에서 진행자 이메일/비밀번호 계정을 만듭니다. 이메일 확인이 필요한 설정이라면 확인된 계정을 사용합니다.
5. `Project Settings > API` 또는 `Connect`에서 **Project URL** 및 **publishable key** (또는 legacy `anon` key)를 확인합니다. `service_role`/`secret` 키는 절대 웹페이지에 넣지 마세요.

## 2) 무료 웹사이트 주소 얻기 (GitHub Pages)
1. https://github.com 에 로그인하고 공개(public) 저장소를 만듭니다. 예: `quiz-party`.
2. **index.html** 파일을 저장소 최상위에 업로드합니다. SQL 파일은 웹에 올릴 필요가 없습니다.
3. `Settings > Pages > Build and deployment > Deploy from branch`에서 `main` `/root`를 선택합니다.
4. 발급된 `https://계정.github.io/quiz-party/` 주소에 접속합니다.
5. 첫 화면에 Supabase Project URL과 publishable/anon key를 입력하고 저장합니다. **진행자용 브라우저에서만 1회 설정하면 되는 구조가 아닙니다.** 참가자 휴대폰도 같은 Supabase 설정을 알아야 하므로, 아래 **배포용 설정 필수** 단계를 사용하세요.

## 3) 배포용 설정 필수 (참가자도 자동 접속)
`index.html`에서 맨 아래의
`if(setup())home();else setupView();`
바로 **위**에 아래 두 줄을 추가하세요. 이는 공개 가능한 프론트엔드 프로젝트 키만 넣는 것입니다.

```javascript
if(!localStorage.getItem('qp_url')) localStorage.setItem('qp_url','https://YOUR_PROJECT.supabase.co');
if(!localStorage.getItem('qp_key')) localStorage.setItem('qp_key','YOUR_PUBLISHABLE_OR_ANON_KEY');
```

GitHub에 수정한 HTML을 다시 업로드하면 참가자 휴대폰도 서버에 연결됩니다. `service_role` 키는 절대로 넣지 마세요.

## 4) 진행
1. 진행자가 `진행자 모드`에서 이메일/비밀번호로 로그인합니다.
2. 8문제와 보기, 정답, 제한시간을 직접 입력하거나 JSON 파일로 가져옵니다.
3. `퀴즈 방 만들기` → 로비에 6자리 코드와 QR 표시.
4. 참가자 120명이 QR로 입장하고 닉네임을 정합니다.
5. 진행자가 문제 시작 → 참가자 휴대폰 선택 → 정답 발표 → 누적 순위 TOP5 → 다음 문제.
6. 마지막에는 **3위→2위→1위 차례 공개**, 축하 음향, 폭죽, 전체 순위 및 CSV 저장.

## Kahoot 원본 8문제 전달 방법
가장 쉬운 방법은 카훗 편집 화면에서 문제/4개 보기/정답을 **8장 스크린샷**으로 찍어 이 채팅에 첨부하는 것입니다. 문제 텍스트를 복사해 보내거나, 해당 내용이 담긴 파일을 올려도 됩니다. 원본을 읽을 수 있게 되면 `questions-template.json`을 실제 문제로 교체할 수 있습니다.

## 중요: 실제 행사 전 부하 테스트
Supabase Free는 시점에 따라 제한이 변동합니다. 2026년 10월 기준 안내 문서상 Realtime 동시 접속 200개, 초당 메시지 100개입니다. 현재 키트는 120명 규모에서 웹소켓 폭주를 피하도록 **약 3.2초 주기의 참가자 HTTP 폴링**을 사용하며, 진행자는 1.8초 주기로 인원수를 확인합니다. 빠른 초단위 동기화는 아닙니다. 120명이 한 번에 답을 제출하면 데이터베이스 부하가 발생할 수 있으므로 **사전 120기기 부하 테스트가 필수**입니다. 실제 운영 안정성을 보장하지 않습니다. Supabase 프로젝트가 장기 비활성화로 일시 중지될 수 있어 행사 직전에 확인하세요.

## 주의사항
- 8문제와 정답을 캡처를 바탕으로 기본 탑재했습니다. 1·5번은 O/X(2개 선택지)입니다. 카훗 원본 문제 자동 추출은 지원하지 않습니다.
- 라이브로 사용하려면 휴대폰과 진행자 PC 모두 인터넷 연결이 필요합니다.
- 별도 음원 파일 없이 Web Audio API로 **효과음과 축하 팬파레**를 만듭니다. 첫 클릭 이후 브라우저에서 재생됩니다. 음향 ON/OFF 버튼이 있습니다.
- 참가자 닉네임과 점수 데이터는 서버 DB에 저장됩니다. 행사 종료 후 보관 정책에 맞게 정리해 주세요.
- 익명 로그인을 ON으로 두면 공개 주소로 누구든 접속 시도를 할 수 있습니다. 행사마다 새 방을 쓰고, 이용량을 관찰하세요.

## 이번 버전 변경 사항
- 보내주신 화면 캡처 기반 8문제와 정답이 기본 탑재되었습니다.
- 6번 부채 사진 포함. GitHub Pages 업로드 시 `assets` 폴더도 반드시 올려주세요.
- **기존에 Supabase SQL을 이미 실행했다면** `schema.sql`의 변경된 `qp_state` 함수를 다시 실행해야 사진 정보가 전달됩니다.
- 외부에서 서비스가 배포되거나 120명 성능이 검증된 것은 아닙니다.
