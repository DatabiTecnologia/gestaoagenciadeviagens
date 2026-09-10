import type { Metadata } from "next";
import "./globals.css";
import "./extended.css";

export const metadata: Metadata = {
  title: "Viaje Bem Gestão",
  description: "Gestão de vendas, financeiro, produtos, fornecedores, comissões e equipe para agências de viagens.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR">
      <body className="antialiased">{children}</body>
    </html>
  );
}
