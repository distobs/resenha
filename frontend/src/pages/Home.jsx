import { Link } from "react-router-dom";

export default function Home() {
  return (
    <main className="home">
      <h1>ResenhaBook</h1>
      <p>Sprint 1 — módulos em desenvolvimento.</p>
      <Link className="pb-link" to="/chat?user=alejandro&name=Alejandro">
        Abrir PB03 — Chat em tempo real
      </Link>
    </main>
  );
}
