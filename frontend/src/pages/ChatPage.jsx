import { useEffect, useRef, useState } from "react";
import { Client } from "@stomp/stompjs";
import { useSearchParams } from "react-router-dom";
import { createConversation, createGroup, getConversations, getGroups, getMessages } from "../api";

export default function ChatPage() {
  const [params] = useSearchParams();
  const userId = params.get("user") || "alejandro";
  const userName = params.get("name") || "Alejandro";
  const [groups, setGroups] = useState([]);
  const [group, setGroup] = useState(null);
  const [conversations, setConversations] = useState([]);
  const [conversation, setConversation] = useState(null);
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState("");
  const [connected, setConnected] = useState(false);
  const [showSidebar, setShowSidebar] = useState(true);
  const [groupFormOpen, setGroupFormOpen] = useState(false);
  const [conversationFormOpen, setConversationFormOpen] = useState(false);
  const [groupName, setGroupName] = useState("");
  const [memberIds, setMemberIds] = useState("mauricio,guilherme");
  const [conversationName, setConversationName] = useState("");
  const [notice, setNotice] = useState("");
  const clientRef = useRef(null);
  const subscriptionRef = useRef(null);
  const bottomRef = useRef(null);

  function report(message) { setNotice(message); }

  async function loadGroups(selectFirst = true) {
    try {
      const data = await getGroups(userId);
      setGroups(data);
      if (selectFirst && data.length) await selectGroup(data[0]);
    } catch { report("Não foi possível carregar os grupos. Confira se o backend está ativo."); }
  }

  async function selectGroup(selectedGroup) {
    setGroup(selectedGroup);
    setShowSidebar(window.innerWidth > 760);
    try {
      const data = await getConversations(selectedGroup.id, userId);
      setConversations(data);
      setConversation(data[0] || null);
      if (!data.length) setMessages([]);
    } catch { report("Não foi possível carregar as conversas deste grupo."); }
  }

  useEffect(() => { loadGroups(); }, [userId]);

  useEffect(() => {
    if (!conversation) return;
    let cancelled = false;
    getMessages(conversation.id, userId)
      .then((history) => { if (!cancelled) setMessages(history); })
      .catch(() => report("Não foi possível carregar o histórico."));
    connectToConversation(conversation.id);
    return () => {
      cancelled = true;
      subscriptionRef.current?.unsubscribe();
      subscriptionRef.current = null;
    };
  }, [conversation?.id, userId]);

  useEffect(() => () => { clientRef.current?.deactivate(); }, []);
  useEffect(() => bottomRef.current?.scrollIntoView({ behavior: "smooth" }), [messages]);

  function connectToConversation(conversationId) {
    if (clientRef.current?.active) { subscribe(conversationId); return; }
    const client = new Client({
      brokerURL: (import.meta.env.VITE_WS_URL || "ws://localhost:8080/ws"),
      connectHeaders: { "X-User-Id": userId },
      reconnectDelay: 3000,
      onConnect: () => { setConnected(true); subscribe(conversationId); },
      onDisconnect: () => setConnected(false),
      onWebSocketClose: () => setConnected(false),
      onStompError: () => report("Falha na conexão em tempo real."),
    });
    client.activate();
    clientRef.current = client;
  }

  function subscribe(conversationId) {
    subscriptionRef.current?.unsubscribe();
    subscriptionRef.current = clientRef.current.subscribe(`/topic/conversations/${conversationId}`, (frame) => {
      setMessages((current) => [...current, JSON.parse(frame.body)]);
      if (document.hidden) document.title = "Nova mensagem — ResenhaBook";
    });
  }

  function sendMessage(event) {
    event.preventDefault();
    if (!text.trim() || !conversation) return;
    if (!clientRef.current?.connected) { report("A conexão em tempo real ainda não está pronta."); return; }
    clientRef.current.publish({
      destination: `/app/chat.send/${conversation.id}`,
      body: JSON.stringify({ text: text.trim(), senderName: userName }),
    });
    setText("");
    setNotice("");
  }

  async function submitGroup(event) {
    event.preventDefault();
    if (!groupName.trim()) return;
    try {
      await createGroup(userId, {
        name: groupName.trim(), description: "",
        memberIds: memberIds.split(",").map((id) => id.trim()).filter(Boolean),
        mapEnabled: false, rankingEnabled: false,
      });
      setGroupName(""); setGroupFormOpen(false); setNotice("");
      await loadGroups();
    } catch { report("Não foi possível criar o grupo."); }
  }

  async function submitConversation(event) {
    event.preventDefault();
    if (!group || !conversationName.trim()) return;
    try {
      await createConversation(group.id, userId, {
        name: conversationName.trim(), visibility: "GROUP", postingPermission: "GROUP",
        allowedViewerIds: [], allowedSenderIds: [],
      });
      const data = await getConversations(group.id, userId);
      setConversations(data); setConversationName(""); setConversationFormOpen(false); setNotice("");
    } catch { report("Somente o administrador do grupo pode criar conversas."); }
  }

  return (
    <main className="chat-page" onFocus={() => { document.title = "ResenhaBook"; }}>
      <aside className={showSidebar ? "chat-sidebar open" : "chat-sidebar"}>
        <div className="sidebar-header"><strong>ResenhaBook</strong><button onClick={() => setGroupFormOpen(!groupFormOpen)}>+ grupo</button></div>
        {groupFormOpen && (
          <form className="inline-form" onSubmit={submitGroup}>
            <label>Nome<input value={groupName} onChange={(e) => setGroupName(e.target.value)} maxLength="100" required /></label>
            <label>Integrantes (IDs separados por vírgula)<input value={memberIds} onChange={(e) => setMemberIds(e.target.value)} /></label>
            <div><button type="submit">Criar</button><button type="button" className="secondary" onClick={() => setGroupFormOpen(false)}>Cancelar</button></div>
          </form>
        )}
        <p className="sidebar-section">Grupos</p>
        {groups.map((item) => <button key={item.id} className={group?.id === item.id ? "sidebar-item selected" : "sidebar-item"} onClick={() => selectGroup(item)}>{item.name}</button>)}
        {group && <>
          <div className="sidebar-section-row"><span>Conversas</span><button onClick={() => setConversationFormOpen(!conversationFormOpen)}>+</button></div>
          {conversationFormOpen && (
            <form className="inline-form" onSubmit={submitConversation}>
              <label>Nome<input value={conversationName} onChange={(e) => setConversationName(e.target.value)} maxLength="100" required /></label>
              <div><button type="submit">Criar</button><button type="button" className="secondary" onClick={() => setConversationFormOpen(false)}>Cancelar</button></div>
            </form>
          )}
          {conversations.map((item) => <button key={item.id} className={conversation?.id === item.id ? "sidebar-item selected" : "sidebar-item"} onClick={() => { setConversation(item); setShowSidebar(window.innerWidth > 760); }}># {item.name}</button>)}
        </>}
        <div className="demo-user">Usuário: <strong>{userName}</strong></div>
      </aside>

      <section className="chat-panel">
        <header className="chat-header">
          <button className="menu-button" aria-label="Abrir menu" onClick={() => setShowSidebar(!showSidebar)}>☰</button>
          <div className="avatar">{userName.charAt(0)}</div>
          <div><strong>{group?.name || "Selecione um grupo"}</strong><small>{conversation ? `# ${conversation.name}` : "Nenhuma conversa"}</small></div>
          <span className={connected ? "connection online" : "connection offline"}>{connected ? "● online" : "● offline"}</span>
        </header>
        <div className="orange-line" />
        {notice && <div className="notice" role="status"><span>{notice}</span><button onClick={() => setNotice("")} aria-label="Fechar aviso">×</button></div>}
        <div className="messages">
          {!conversation && <div className="empty-chat">Selecione uma conversa.</div>}
          {messages.map((message) => {
            const mine = message.senderId === userId;
            return <div key={message.id} className={mine ? "message-row mine" : "message-row"}>
              <div className={mine ? "bubble bubble-mine" : "bubble bubble-other"}>
                {!mine && <span className="sender">{message.senderName}</span>}
                <span>{message.text}</span>
                <time>{new Date(message.sentAt).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}</time>
              </div>
            </div>;
          })}
          <div ref={bottomRef} />
        </div>
        <form className="message-form" onSubmit={sendMessage}>
          <input type="text" placeholder="Digite..." value={text} disabled={!conversation} onChange={(e) => setText(e.target.value)} maxLength="1000" />
          <button type="submit" disabled={!conversation} title="Enviar">➜</button>
        </form>
      </section>
    </main>
  );
}
