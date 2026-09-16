# ResenhaBook — PB03

Projeto React + Spring Boot + MongoDB para chat em grupo em tempo real.

## Executar

1. Inicie o MongoDB: `docker compose up -d`
2. Em outro terminal: `cd backend && mvn spring-boot:run`
3. Em outro terminal: `cd frontend && npm run dev`
4. Abra `http://localhost:5173`

Teste simultâneo:

- `http://localhost:5173/chat?user=alejandro&name=Alejandro`
- `http://localhost:5173/chat?user=mauricio&name=Mauricio`

O cabeçalho `X-User-Id` é apenas uma identidade de demonstração. Quando o PB01
for integrado, ele deve ser substituído pela identidade autenticada do usuário.
