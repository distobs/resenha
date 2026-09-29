import { Link } from "react-router-dom";

export default function Home() {
  return (
  // Trivial.
    <main className="home">
      <h1>ResenhaBook</h1>
      <p>Sprint 1 — módulos em desenvolvimento.</p>
		  {
			  // a href só que melhor com negócio de rota.
		  }
      <Link className="pb-link" to="/chat?user=alejandro&name=Alejandro">
        Abrir PB03 — Chat em tempo real
      </Link>
    </main>
  );
}
