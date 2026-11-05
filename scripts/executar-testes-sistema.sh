#!/usr/bin/env bash
# Execução dos casos de teste de sistema CT02–CT17 (Azure Test Plans) contra a PetHealthAPI local.
# Uso (Git Bash, na pasta do repositório da API):  bash executar-testes-sistema.sh | tee execucao-testes-sistema.txt
# Pré-requisito: CT01 executado (tutora Ana Souza cadastrada).

BASE="${BASE:-http://localhost:8080}"
PASS=0; FAIL=0

req() { # req METODO CAMINHO [JSON]
  local m=$1 p=$2 b=$3 resp
  if [ -n "$b" ]; then
    # corpo enviado por pipe (bytes UTF-8 intactos; no Git Bash o argumento -d corrompe acentos)
    resp=$(printf '%s' "$b" | curl -s -w '\n%{http_code}' -X "$m" "$BASE$p" -H 'Content-Type: application/json; charset=utf-8' --data-binary @-)
  else
    resp=$(curl -s -w '\n%{http_code}' -X "$m" "$BASE$p")
  fi
  CODE=$(printf '%s' "$resp" | tail -n1)
  BODY=$(printf '%s' "$resp" | sed '$d')
}
ok()   { PASS=$((PASS+1)); echo "  [PASS] $1"; }
nok()  { FAIL=$((FAIL+1)); echo "  [FAIL] $1  (obtido: HTTP $CODE ${BODY:0:200})"; }
expect() { # expect DESCRICAO CODIGO [TRECHO_NO_CORPO]
  if [ "$CODE" = "$2" ] && { [ -z "$3" ] || printf '%s' "$BODY" | grep -qF "$3"; }; then ok "$1 -> HTTP $CODE"; else nok "$1 (esperado HTTP $2 ${3:+contendo '$3'})"; fi
}
count() { printf '%s' "$BODY" | grep -o "\"$1\"" | wc -l | tr -d ' '; }
id_of() { printf '%s' "$BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
title() { echo; echo "=== $1 ==="; }

D=$(date -u +%F)                       # a API roda em UTC no container
dt() { date -u -d "$D $1 days" +%F; }

echo "Execução dos testes de sistema - Pet Health API - $(date '+%d/%m/%Y %H:%M')"
echo "Ambiente: $BASE (docker compose: API .NET 8 + Oracle XE 21) | data de referência D = $D"

req GET "/api/Tutores/email/ana.souza@pethealth.com"
TUTOR_ID=$(id_of)
if [ -z "$TUTOR_ID" ]; then echo "ERRO: execute o CT01 antes (tutora Ana Souza não encontrada)."; exit 1; fi
echo "TUTOR_ID (Ana Souza) = $TUTOR_ID"

title "CT02 - Bloqueio de tutor duplicado ou inválido (PBI 1)"
req GET /api/Tutores; N=$(count telefone); echo "  tutores antes: $N"
req POST /api/Tutores '{"nome":"Ana Clone","email":"ana.souza@pethealth.com","telefone":"11900000000"}'
expect "Iteração 1 - e-mail duplicado" 400 "cadastrado com este email"
req POST /api/Tutores '{"nome":"Carla Dias","email":"carla.pethealth.com","telefone":"11900000001"}'
expect "Iteração 2 - e-mail inválido" 400 "Email inv"
req POST /api/Tutores '{"nome":"","email":"sem.nome@pethealth.com","telefone":"11900000002"}'
expect "Iteração 3 - nome vazio" 400 "Nome"
req GET /api/Tutores; [ "$(count telefone)" = "$N" ] && ok "Nenhum tutor gravado (continua $N)" || nok "Quantidade de tutores mudou"

title "CT03 - Cadastro de pet válido e valores-limite (PBI 1)"
req POST /api/Pets "{\"nome\":\"Thor\",\"especie\":\"Cachorro\",\"raca\":\"Labrador\",\"idade\":3,\"peso\":28.5,\"sexo\":\"Macho\",\"castrado\":false,\"tutorId\":$TUTOR_ID}"
expect "Iteração 1 - Thor" 201 '"nome":"Thor"'; PET_ID=$(id_of)
req POST /api/Pets "{\"nome\":\"Mia\",\"especie\":\"Gato\",\"raca\":\"Siamês\",\"idade\":1,\"peso\":4.2,\"sexo\":\"Fêmea\",\"castrado\":true,\"tutorId\":$TUTOR_ID}"
expect "Iteração 2 - Mia" 201 '"nome":"Mia"'; MIA_ID=$(id_of)
req POST /api/Pets "{\"nome\":\"Pipoca\",\"especie\":\"Hamster\",\"raca\":\"Sírio\",\"idade\":0,\"peso\":0.1,\"sexo\":\"Fêmea\",\"castrado\":false,\"tutorId\":$TUTOR_ID}"
expect "Iteração 3 - Pipoca (idade 0, peso 0.1)" 201 '"nome":"Pipoca"'
req POST /api/Pets "{\"nome\":\"Duque\",\"especie\":\"Cachorro\",\"raca\":\"São Bernardo\",\"idade\":30,\"peso\":200,\"sexo\":\"Macho\",\"castrado\":true,\"tutorId\":$TUTOR_ID}"
expect "Iteração 4 - Duque (idade 30, peso 200)" 201 '"nome":"Duque"'
echo "  PET_ID (Thor) = $PET_ID | MIA_ID (Mia) = $MIA_ID"
req GET "/api/Pets/$PET_ID"; expect "GET /api/Pets/$PET_ID" 200 '"vacinas":[]'
req GET "/api/Tutores/$TUTOR_ID/pets"; expect "Pets do tutor contêm Thor" 200 '"nome":"Thor"'

title "CT04 - Rejeição de pet inválido (PBI 1)"
req GET /api/Pets; N=$(count tutorId); echo "  pets antes: $N"
req POST /api/Pets "{\"nome\":\"\",\"especie\":\"Cachorro\",\"idade\":3,\"peso\":10,\"tutorId\":$TUTOR_ID}"; expect "Iteração 1 - nome vazio" 400 "Nome"
req POST /api/Pets "{\"nome\":\"Rex\",\"especie\":\"Cachorro\",\"idade\":31,\"peso\":10,\"tutorId\":$TUTOR_ID}"; expect "Iteração 2 - idade 31" 400 "Idade deve ser entre 0 e 30 anos"
req POST /api/Pets "{\"nome\":\"Rex\",\"especie\":\"Cachorro\",\"idade\":3,\"peso\":0,\"tutorId\":$TUTOR_ID}"; expect "Iteração 3 - peso 0" 400 "Peso deve ser entre 0.1kg e 200kg"
req POST /api/Pets "{\"nome\":\"Rex\",\"especie\":\"Cachorro\",\"idade\":3,\"peso\":250,\"tutorId\":$TUTOR_ID}"; expect "Iteração 4 - peso 250" 400 "Peso deve ser entre 0.1kg e 200kg"
req POST /api/Pets '{"nome":"Rex","especie":"Cachorro","idade":3,"peso":10,"tutorId":99999}'; expect "Iteração 5 - tutor inexistente" 400 "Tutor com ID 99999"
req GET /api/Pets; [ "$(count tutorId)" = "$N" ] && ok "Nenhum pet gravado (continua $N)" || nok "Quantidade de pets mudou"

title "CT05 - Edição dos dados do pet (PBI 2)"
req GET "/api/Pets/$PET_ID"; expect "GET dados atuais do Thor" 200 '"nome":"Thor"'
req PUT "/api/Pets/$PET_ID" "{\"id\":$PET_ID,\"nome\":\"Thor\",\"especie\":\"Cachorro\",\"raca\":\"Labrador\",\"idade\":4,\"peso\":30.2,\"sexo\":\"Macho\",\"castrado\":true,\"alergias\":\"Frango\",\"tutorId\":$TUTOR_ID}"
expect "Iteração 1 - PUT idade 4, peso 30.2, Frango" 204
req GET "/api/Pets/$PET_ID"; expect "Iteração 1 - GET confirma alergias Frango" 200 '"alergias":"Frango"'
req PUT "/api/Pets/$PET_ID" "{\"id\":$PET_ID,\"nome\":\"Thor\",\"especie\":\"Cachorro\",\"raca\":\"Labrador\",\"idade\":4,\"peso\":29,\"sexo\":\"Macho\",\"castrado\":true,\"alergias\":\"Nenhuma\",\"tutorId\":$TUTOR_ID}"
expect "Iteração 2 - PUT peso 29, Nenhuma" 204
req GET "/api/Pets/$PET_ID"; expect "Iteração 2 - GET confirma peso 29" 200 '"peso":29'

title "CT06 - Rejeição de edição inválida (PBI 2)"
req PUT "/api/Pets/$PET_ID" "{\"id\":99998,\"nome\":\"Thor\",\"especie\":\"Cachorro\",\"peso\":30,\"tutorId\":$TUTOR_ID}"; expect "Iteração 1 - ID divergente" 400 "O ID da rota"
req PUT /api/Pets/99999 "{\"id\":99999,\"nome\":\"Thor\",\"especie\":\"Cachorro\",\"peso\":30,\"tutorId\":$TUTOR_ID}"; expect "Iteração 2 - pet inexistente" 404 "Pet com ID 99999"
req PUT "/api/Pets/$PET_ID" "{\"id\":$PET_ID,\"nome\":\"Thor\",\"especie\":\"Cachorro\",\"peso\":0,\"tutorId\":$TUTOR_ID}"; expect "Iteração 3 - peso 0" 400 "Peso deve ser entre 0.1kg e 200kg"
req GET "/api/Pets/$PET_ID"; expect "Peso do Thor continua 29" 200 '"peso":29'

title "CT07 - Registro de vacina (PBI 3)"
req POST /api/Vacinas "{\"nome\":\"V10 (Polivalente)\",\"dataAplicacao\":\"2026-03-10\",\"dataProximaDose\":\"2027-03-10\",\"fabricante\":\"Zoetis\",\"lote\":\"Z2026A1\",\"veterinario\":\"Dra. Paula Reis\",\"petId\":$PET_ID}"
expect "Iteração 1 - V10" 201 '"lote":"Z2026A1"'; V1=$(id_of)
req GET "/api/Vacinas/$V1"; expect "GET vacina $V1" 200 '"fabricante":"Zoetis"'
req POST /api/Vacinas "{\"nome\":\"Antirrábica\",\"dataAplicacao\":\"2026-03-10\",\"dataProximaDose\":\"2027-03-10\",\"fabricante\":\"MSD\",\"lote\":\"R7781\",\"veterinario\":\"Dra. Paula Reis\",\"petId\":$PET_ID}"
expect "Iteração 2 - Antirrábica" 201 '"lote":"R7781"'; V2=$(id_of)
req GET "/api/Vacinas/$V2"; expect "GET vacina $V2" 200 '"fabricante":"MSD"'

title "CT08 - Rejeição de vacina inválida (PBI 3)"
req POST /api/Vacinas "{\"nome\":\"\",\"dataAplicacao\":\"2026-03-10\",\"petId\":$PET_ID}"; expect "Iteração 1 - sem nome" 400 "Nome da vacina"
req POST /api/Vacinas '{"nome":"V10 (Polivalente)","dataAplicacao":"2026-03-10","petId":99999}'; expect "Iteração 2 - pet inexistente" 400 "Pet com ID 99999"
req GET "/api/Vacinas/pet/$PET_ID"; [ "$(count lote)" = "2" ] && ok "Carteira do Thor continua com 2 vacinas" || nok "Carteira não tem 2 vacinas"

title "CT09 - Carteira de vacinação (PBI 4)"
req GET "/api/Vacinas/pet/$PET_ID"; expect "Iteração 1 - carteira do Thor" 200 "Antirr"; [ "$(count lote)" = "2" ] && ok "2 vacinas na carteira" || nok "quantidade diferente de 2"
printf '%s' "$BODY" | grep -qiE 'email|telefone' && nok "Carteira expõe dados do tutor" || ok "Carteira sem e-mail/telefone do tutor"
req GET "/api/Vacinas/pet/$MIA_ID"; expect "Iteração 2 - carteira da Mia (vazia)" 200 "[]"
req GET /api/Vacinas/pet/99999; expect "Iteração 3 - pet inexistente" 404 "Pet com ID 99999"

title "CT10 - Consultas e ordem do histórico (PBI 5)"
req POST /api/Consultas "{\"dataConsulta\":\"2026-05-12\",\"motivo\":\"Check-up anual\",\"veterinario\":\"Dra. Paula Reis\",\"clinica\":\"Clínica VetCare\",\"diagnostico\":\"Saudável\",\"tratamento\":\"Manter rotina de vacinas\",\"custo\":180.00,\"petId\":$PET_ID}"
expect "Iteração 1 - Check-up anual" 201 "Check-up anual"
req POST /api/Consultas "{\"dataConsulta\":\"2026-09-02\",\"motivo\":\"Coceira na orelha\",\"veterinario\":\"Dra. Paula Reis\",\"clinica\":\"Clínica VetCare\",\"diagnostico\":\"Otite externa leve\",\"tratamento\":\"Limpeza + gotas por 7 dias\",\"custo\":250.00,\"petId\":$PET_ID}"
expect "Iteração 2 - Coceira na orelha" 201 "Coceira na orelha"
req GET "/api/Consultas/pet/$PET_ID"
FIRST=$(printf '%s' "$BODY" | grep -o '"motivo":"[^"]*"' | head -1)
[ "$FIRST" = '"motivo":"Coceira na orelha"' ] && ok "Histórico começa pela mais recente (02/09)" || nok "Ordem do histórico incorreta ($FIRST)"

title "CT11 - Medicamentos e lista de ativos (PBI 5)"
req POST /api/Medicamentos "{\"nome\":\"Otomax\",\"dosagem\":\"5 gotas\",\"frequencia\":\"12 em 12 horas\",\"dataInicio\":\"2026-09-02\",\"dataFim\":\"2026-09-09\",\"veterinarioPrescreveu\":\"Dra. Paula Reis\",\"ativo\":true,\"petId\":$PET_ID}"
expect "Iteração 1 - Otomax ativo" 201 '"ativo":true'
req POST /api/Medicamentos "{\"nome\":\"Apoquel 5,4 mg\",\"dosagem\":\"1 comprimido\",\"frequencia\":\"1x ao dia\",\"dataInicio\":\"2026-09-02\",\"dataFim\":\"2026-09-09\",\"veterinarioPrescreveu\":\"Dra. Paula Reis\",\"ativo\":false,\"petId\":$PET_ID}"
expect "Iteração 2 - Apoquel inativo" 201 '"ativo":false'
req GET /api/Medicamentos/ativos
printf '%s' "$BODY" | grep -qF Otomax && ok "Otomax aparece nos ativos" || nok "Otomax ausente dos ativos"
printf '%s' "$BODY" | grep -qF Apoquel && nok "Apoquel apareceu nos ativos" || ok "Apoquel não aparece nos ativos"
req GET "/api/Medicamentos/pet/$PET_ID"; expect "Medicamentos do Thor" 200 "Apoquel"

title "CT12 - Rejeição de registro clínico inválido (PBI 5)"
req POST /api/Consultas "{\"dataConsulta\":\"2026-10-01\",\"motivo\":\"\",\"petId\":$PET_ID}"; expect "Iteração 1 - consulta sem motivo" 400 "Motivo"
req POST /api/Consultas '{"dataConsulta":"2026-10-01","motivo":"Vomito","petId":99999}'; expect "Iteração 2 - consulta de pet inexistente" 400 "Pet com ID 99999"
req POST /api/Medicamentos "{\"nome\":\"Dipirona\",\"dosagem\":\"\",\"frequencia\":\"8/8h\",\"dataInicio\":\"2026-10-01\",\"petId\":$PET_ID}"; expect "Iteração 3 - medicamento sem dosagem" 400 "Dosagem"
req GET "/api/Consultas/pet/$PET_ID"; C=$(count motivo); req GET "/api/Medicamentos/pet/$PET_ID"; M=$(count dosagem)
[ "$C" = "2" ] && [ "$M" = "2" ] && ok "Continuam 2 consultas e 2 medicamentos" || nok "Consultas=$C Medicamentos=$M"

title "CT13 - Rastreabilidade X-Correlation-ID (PBI 6)"
H=$(curl -s -D - -o /dev/null -H "X-Correlation-ID: CT13-AUDIT-0001" "$BASE/api/Pets/$PET_ID" | tr -d '\r' | grep -i '^x-correlation-id:')
echo "  $H"; printf '%s' "$H" | grep -qi 'CT13-AUDIT-0001' && ok "Iteração 1 - ID enviado devolvido" || nok "Iteração 1 - cabeçalho diferente"
H=$(curl -s -D - -o /dev/null "$BASE/api/Pets/$PET_ID" | tr -d '\r' | grep -i '^x-correlation-id:')
echo "  $H"; printf '%s' "$H" | grep -qiE 'x-correlation-id: [0-9a-f-]{36}$' && ok "Iteração 2 - GUID gerado (36 caracteres)" || nok "Iteração 2 - GUID não gerado"
if docker compose logs api 2>/dev/null | grep -q CT13-AUDIT-0001; then ok "ID aparece no log da API"; else echo "  [INFO] Conferir manualmente: docker compose logs api | grep CT13-AUDIT-0001"; fi

title "CT14 - Respostas sem dados internos nem pessoais (PBI 6)"
for R in "/api/Pets/99999" "/api/Vacinas/pet/$PET_ID" "/api/Medicamentos/ativos"; do
  req GET "$R"
  if printf '%s' "$BODY" | grep -qiE 'oracle|ora-|tb_ph|stack|exception|email|telefone'; then nok "$R expõe dado interno/pessoal"; else ok "$R (HTTP $CODE) sem stack, Oracle, tabela, e-mail ou telefone"; fi
done
req GET /api/Pets/99999; expect "Erro 404 só com mensagem amigável" 404 '{"mensagem":"Pet com ID 99999'

title "CT16 - Vacinas a vencer em 30 dias (PBI 7)"
for L in "Reforço Gripe Canina|10|sim" "Reforço Giárdia|30|sim" "Reforço Leishmaniose|31|nao" "Reforço V8 atrasado|-5|nao"; do
  IFS='|' read -r NOME DIAS APARECE <<< "$L"
  req POST /api/Vacinas "{\"nome\":\"$NOME\",\"dataAplicacao\":\"2026-01-10\",\"dataProximaDose\":\"$(dt "$DIAS")\",\"petId\":$PET_ID}"
  expect "POST $NOME (próxima dose $(dt "$DIAS"))" 201
done
req GET /api/Vacinas/vencendo
for L in "Gripe Canina|sim" "rdia|sim" "Leishmaniose|nao" "V8 atrasado|nao"; do
  IFS='|' read -r NOME APARECE <<< "$L"
  if printf '%s' "$BODY" | grep -qF "$NOME"; then [ "$APARECE" = sim ] && ok "$NOME aparece" || nok "$NOME não deveria aparecer"
  else [ "$APARECE" = nao ] && ok "$NOME não aparece" || nok "$NOME deveria aparecer"; fi
done
DATAS=$(printf '%s' "$BODY" | grep -o '"dataProximaDose":"[^"]*"' | cut -d'"' -f4)
[ "$DATAS" = "$(printf '%s\n' "$DATAS" | sort)" ] && ok "Lista em ordem crescente de próxima dose" || nok "Lista fora de ordem"

title "CT17 - Retornos de consulta pendentes (PBI 7)"
req POST /api/Consultas "{\"dataConsulta\":\"$D\",\"motivo\":\"Pós-operatório castração\",\"dataRetorno\":\"$(dt 7)\",\"petId\":$PET_ID}"; expect "POST retorno em $(dt 7)" 201
req POST /api/Consultas "{\"dataConsulta\":\"$D\",\"motivo\":\"Exame de sangue\",\"dataRetorno\":\"$(dt 45)\",\"petId\":$PET_ID}"; expect "POST retorno em $(dt 45)" 201
req GET /api/Consultas/retornos
printf '%s' "$BODY" | grep -qF "castra" && ok "Pós-operatório castração aparece" || nok "Pós-operatório castração deveria aparecer"
printf '%s' "$BODY" | grep -qF "Exame de sangue" && nok "Exame de sangue não deveria aparecer" || ok "Exame de sangue não aparece"

title "CT15 - Credencial protegida e monitoramento do banco (PBI 6)"
if grep -qi password src/PetHealthAPI/appsettings.json 2>/dev/null; then nok "Senha encontrada no appsettings.json"
elif [ -f src/PetHealthAPI/appsettings.json ]; then ok "appsettings.json sem senha (connection string via variável de ambiente)"
else echo "  [INFO] Rode o script na pasta do repositório da API para checar o appsettings.json"; fi
req GET /health; printf '%s' "$BODY" | tr -d ' \n' | grep -qE '"nome":"oracle-database","status":"Healthy"' && ok "Iteração 1 - banco ligado: oracle-database Healthy" || nok "oracle-database não está Healthy"
docker stop pethealth-oracle >/dev/null
req GET /health; printf '%s' "$BODY" | tr -d ' \n' | grep -qE '"nome":"oracle-database","status":"Unhealthy"' && ok "Iteração 2 - banco parado: oracle-database Unhealthy" || nok "oracle-database não ficou Unhealthy"
docker start pethealth-oracle >/dev/null
echo "  Religando o Oracle (aguarde até 2 min)..."
for i in $(seq 1 24); do sleep 5; req GET /health; printf '%s' "$BODY" | tr -d ' \n' | grep -qE '"nome":"oracle-database","status":"Healthy"' && break; done
echo "  Oracle de volta: $(printf '%s' "$BODY" | tr -d ' \n' | grep -oE '"nome":"oracle-database","status":"[A-Za-z]*"')"

echo
echo "=================================================="
echo "RESUMO: $PASS verificações aprovadas, $FAIL reprovadas"
echo "=================================================="
