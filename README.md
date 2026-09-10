# Viaje Bem Gestão

Sistema SaaS de gestão para agências de viagens.

## Módulos

- vendas, clientes, produtos e fornecedores;
- recebimentos, pagamentos, comissões e RAV;
- regras comerciais e parcelamento por fornecedor;
- marketing, campanhas, leads e atribuição de vendas;
- viagens, viajantes, eventos, check-in e alertas;
- WhatsApp para agência, cliente e agente responsável;
- usuários, perfis, permissões e identidade visual por agência.

## Arquitetura

- interface: React + TypeScript + Vinext;
- componentes: shadcn/ui;
- banco e autenticação: Supabase/PostgreSQL;
- segurança: Row Level Security com isolamento por organização;
- hospedagem atual: OpenAI Sites.

As migrações ficam em `supabase/migrations`. Nunca coloque chaves
`service_role` no navegador ou no repositório.

## Desenvolvimento

1. Copie `.env.example` para `.env.local`.
2. Instale as dependências com `pnpm install`.
3. Execute `pnpm dev`.
4. Gere a produção com `pnpm build`.
