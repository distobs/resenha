import { BrowserRouter, Route, Routes } from "react-router-dom";
import Home from "./pages/Home";
import ChatPage from "./pages/ChatPage";
import "./styles.css";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/chat" element={<ChatPage />} />
      </Routes>
    </BrowserRouter>
  );
}
