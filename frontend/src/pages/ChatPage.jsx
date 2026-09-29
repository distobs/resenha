/* Este arquivo define um componente roteado em App.jsx.
* Imports de utilitários externos.
* useEffect:
*  Recebe um callback e, opcionalmente, um array como segundo argumento.
*  O callback pode, opcionalmente, retornar uma função de cleanup,
*  executada toda vez que o efeito for ativado novamente, ou toda vez que o
*  componente é desmontado.
*  Sem segundo argumento:
*    O efeito roda toda vez que o componente é renderizado novamente.
*    A função de retorno roda toda vez que o componente é re-renderizado
*    ou quando ele é desmontado.
*  Segundo argumento = array vazio:
*    O efeito roda roda apenas quando o componente é montado.
*    Cleanup toda vez que o componente desmonta.
*  Segundo argumento = array de dependências:
*    O efeito roda toda vez que uma dependência muda.
*    Cleanup toda vez que o efeito roda novamente e quando o componente é
*    desmontado.
*  useRef:
*    Cria uma ref, um objeto que, associado a um componente até o desmonte,
*    permite que o valor de uma variável seja retido entre renderizações.
*  useState:
*    Retorna um array de duas variáveis. A primeira guarda o estado atual
*    (começando pelo inicial especificado no useState(@parametro)) e a segunda
*    é uma função que atualiza o estado atual e causa uma re-renderização.
*/
import { useEffect, useRef, useState } from "react";
/* STOMP é um protocolo para mensagens de texto que funciona no modelo
* publisher-subscriber. Cada cliente se conecta a um broker, que pode fornecer
* destinos nos quais o cliente pode se inscrever. O cliente pode enviar
* mensagens para certos destinos, que são roteadas pelo servidor ou broker de
* acordo com as regras definidas.
*
* O objeto Client representa um cliente.
*/
import { Client } from "@stomp/stompjs";
/*
* Usado para trabalhar com parâmetros de URL.
*/
import { useSearchParams } from "react-router-dom";
/* Imports de utilitários internos */
import {
	createConversation, createGroup,
	getConversations, getGroups, getMessages
} from "../api";

export default function ChatPage() {
	/* Recupera parâmetros da URL. Esses parâmetros guardam o nome e o nome de
	* usuário. */
	const [params] = useSearchParams();
	const userId = params.get("user") || "alejandro";
	const userName = params.get("name") || "Alejandro";

	/* Uma lista dos grupos em que está o usuário, inicialmente vazia. */
	const [groups, setGroups] = useState([]);
	/* O grupo atualmente selecionado. Inicialmente, nenhum. */
	const [group, setGroup] = useState(null);

	/* As conversas (subgrupos) de um grupo. */
	const [conversations, setConversations] = useState([]);
	/* A conversa selecionada. */
	const [conversation, setConversation] = useState(null);

	/* As mensagens da conversa selecionada */
	const [messages, setMessages] = useState([]);

	/* O texto sendo digitado pelo usuário. */
	const [text, setText] = useState("");

	/* Estamos conectados ao servidor? */
	const [connected, setConnected] = useState(false);

	/* Devemos mostrar a sidebar? Responsividade: verdadeiro ou falso a depender
	* do tamanho da tela. */
	const [showSidebar, setShowSidebar] = useState(true);

	/* Formulário de criação de grupo? */
	const [groupFormOpen, setGroupFormOpen] = useState(false);
	/* Formulário de criação de conversa? */
	const [conversationFormOpen, setConversationFormOpen] = useState(false);

	/* Dados de grupo e conversa para a criação */
	const [groupName, setGroupName] = useState("");
	const [memberIds, setMemberIds] = useState("mauricio,guilherme");
	const [conversationName, setConversationName] = useState("");

	/* Aviso. */
	const [notice, setNotice] = useState("");

	/* Objeto de cliente. */
	const clientRef = useRef(null);

	/* Subscrição de um cliente a um destino. */
	const subscriptionRef = useRef(null);

	/* Usado em uma div para causar um efeito suave de rolagem até a última
	* mensagem ao re-renderizar. */
	const bottomRef = useRef(null);

	/* Estabelece um aviso. */
	function report(message) {
		setNotice(message);
	}

	async function loadGroups(selectFirst = true) {
		try {
			/* Requisição. */
			const data = await getGroups(userId);
			/* Atualiza os grupos de acordo com a resposta à requisição.  */
			setGroups(data);
			/* Se queremos selecionar o primeiro grupo da resposta e se houver
			* primeiro grupo... */
			if (selectFirst && data.length) {
				/* Seleciona grupo.  */
				await selectGroup(data[0]);
			}
		} catch {
			report("Não foi possível carregar os grupos. Confira se o backend está ativo.");
		}
	}

	async function selectGroup(selectedGroup) {
		/* Estado: estamos nesse grupo. */
		setGroup(selectedGroup);
		setShowSidebar(window.innerWidth > 760);
		try {
			/* Pegamos as conversas em um grupo. */
			const data = await getConversations(selectedGroup.id, userId);
			setConversations(data);
			setConversation(data[0] || null);
			if (!data.length) setMessages([]);
		} catch { report("Não foi possível carregar as conversas deste grupo."); }
	}

	/* Quando userId é alterado, re-renderizar carregando os grupos. */
	useEffect(() => { loadGroups(); }, [userId]);

	/* Quando a conversa selecionada é mudada, ou quando o usuário é mudado. */
	useEffect(() => {
		/* Não fazer nada se não houver conversa selecionada. */
		if (!conversation) return;
		/* Evita race conditions. */
		let cancelled = false;
		/* Recupera as mensagens da conversa. */
		getMessages(conversation.id, userId)
			.then((history) => { if (!cancelled) setMessages(history); })
			.catch(() => report("Não foi possível carregar o histórico."));
		/* Conecta à conversa selecionada. */
		connectToConversation(conversation.id);
		return () => {
			cancelled = true;
			/* De-subscreve. */
			subscriptionRef.current?.unsubscribe();
			subscriptionRef.current = null;
		};
	}, [conversation?.id, userId]);

	// Define uma função de cleanup que desativa o cliente.
	useEffect(() => () => { clientRef.current?.deactivate(); }, []);
	useEffect(() => bottomRef.current?.scrollIntoView({ behavior: "smooth" }), [messages]);

	function connectToConversation(conversationId) {
		// Temos um cliente?
		if (clientRef.current?.active) {
			// Subscrevemos à conversa do parâmetro.
			subscribe(conversationId);
			return;
		}

		// Não temos um cliente? Criamos um.
		const client = new Client({
			brokerURL: (import.meta.env.VITE_WS_URL || "ws://localhost:8080/ws"),
			connectHeaders: {
				"X-User-Id": userId
			},
			reconnectDelay: 3000,
			onConnect: () => {
				setConnected(true); subscribe(conversationId);
			},
			onDisconnect: () => setConnected(false),
			onWebSocketClose: () => setConnected(false),
			onStompError: () => report("Falha na conexão em tempo real."),
		});

		client.activate();
		clientRef.current = client;
	}

	// Ao subscrever a uma conversa...
	function subscribe(conversationId) {
		// Nos desconectamos da conversa atual (se houver).
		subscriptionRef.current?.unsubscribe();
		// E nos inscrevemos à outra
		subscriptionRef.current = clientRef.current.subscribe(`/topic/conversations/${conversationId}`, (frame) => {
			// Carregando as mensagens da conversa.
			setMessages((current) => [...current, JSON.parse(frame.body)]);
			// Se a página não estiver focada...
			if (document.hidden)
				// Mudamos o título.
				document.title = "Nova mensagem — ResenhaBook";
		});
	}

	// Callback de submissão de formulário de mensagem.
	function sendMessage(event) {
		event.preventDefault();

		// Previne mensagem vazia ou enviada para lugar nenhum.
		if (!text.trim() || !conversation) {
			return;
		}

		if (!clientRef.current?.connected) {
			report("A conexão em tempo real ainda não está pronta.");
			return;
		}

		// Publica no servidor.
		clientRef.current.publish({
			destination: `/app/chat.send/${conversation.id}`,
			body: JSON.stringify({
				text: text.trim(),
				senderName: userName
			}),
		});

		setText("");
		setNotice("");
	}

	// Callback de formulário de criação de grupo.
	async function submitGroup(event) {
		event.preventDefault();

		// Nome vazio.
		if (!groupName.trim()) {
			return;
		}

		try {
			// API.
			await createGroup(userId, {
				name: groupName.trim(), description: "",
				memberIds: memberIds.split(",").map((id) => id.trim()).filter(Boolean),
				mapEnabled: false, rankingEnabled: false,
			});

			// Reseta as variáveis usadas.
			setGroupName("");
			setGroupFormOpen(false);
			setNotice("");

			await loadGroups();
		} catch {
			report("Não foi possível criar o grupo.");
		}
	}

	// Callback de formulário de criação de conversa.
	async function submitConversation(event) {
		event.preventDefault();
		// Conversa em grupo nenhum ou sem nome.
		if (!group || !conversationName.trim()) {
			return;
		}

		try {
			// API.
			await createConversation(group.id, userId, {
				name: conversationName.trim(), visibility: "GROUP", postingPermission: "GROUP",
				allowedViewerIds: [], allowedSenderIds: [],
			});

			const data = await getConversations(group.id, userId);

			// Reset.
			setConversations(data);
			setConversationName("");
			setConversationFormOpen(false);
			setNotice("");
		} catch {
			report("Somente o administrador do grupo pode criar conversas.");
		}
	}

	// O que será renderizado.
	return (
		<main
			className="chat-page"
			// Título focado.
			onFocus={
				() => {
					document.title = "ResenhaBook";
				}
			}
		>
			<aside className={
				showSidebar ? "chat-sidebar open" : "chat-sidebar"
			}>
				<div className="sidebar-header">
					<strong>ResenhaBook</strong>
					<button onClick={
						() => setGroupFormOpen(!groupFormOpen)
					}>
						+ grupo
					</button>
				</div>

				{
					// Renderização condicional: se o formulário está aberto, o renderizamos.
					groupFormOpen &&
					(
						// Formulário básico.
						<form className="inline-form" onSubmit={submitGroup}>
							<label>
								Nome
								<input
								value={groupName}
								onChange={
									(e) => setGroupName(e.target.value)
								}
								maxLength="100"
								required />
							</label>

							<label>
								Integrantes (IDs separados por vírgula)
								<input
								value={memberIds}
								onChange={
									(e) => setMemberIds(e.target.value)}
								/>
							</label>

							<div>
								<button type="submit">
									Criar
								</button>
								<button
									type="button"
									className="secondary"
									onClick={
										() => setGroupFormOpen(false)
									}>
										Cancelar
									</button>
							</div>
						</form>
					)
				}

				<p className="sidebar-section">Grupos</p>

				{
					// Para cada grupo...
					groups.map(
						(item) =>
						// Criamos um botão para selecioná-lo.
						<button
							key={item.id}
							className={group?.id === item.id ? "sidebar-item selected" : "sidebar-item"}
							onClick={() =>
								selectGroup(item)}>
									{item.name}
								</button>
					)
				}

				{
					// Se temos um grupo selecionado...
					group &&
					// Fragment
					<>
						{
							// Mostramos as conversas dele.
						}
						<div className="sidebar-section-row">
							<span>
								Conversas
							</span>
							<button
								onClick={
									// Adicionar uma conversa.
									() =>
									setConversationFormOpen(!conversationFormOpen)
								}>
									+
								</button>
						</div>

						{
							// Se queremos criar uma conversa...
							conversationFormOpen &&
							// Exibimos o formulário.
							(
								<form className="inline-form" onSubmit={submitConversation}>
									<label>
										Nome
										<input
										value={conversationName}
										onChange={
											(e) => setConversationName(e.target.value)
										}
										maxLength="100"
										required />
									</label>
									<div>
										<button type="submit">
											Criar
										</button>
										<button
											type="button"
											className="secondary"
											onClick={
												() =>
												setConversationFormOpen(false)
											}
										>
											Cancelar
										</button>
									</div>
								</form>
							)
						}
						{
							// Exibimos as conversas do grupo.
							conversations.map(
								(item) =>
								<button
									key={item.id}
									className={conversation?.id === item.id ?
										"sidebar-item selected" : "sidebar-item"
									}
									onClick={
										() => {
											setConversation(item);
											setShowSidebar(window.innerWidth > 760);
										}
									}
								>
									# {item.name}
								</button>
							)
						}
					</>
				}

				{
					// Nosso nome.
				}
				<div className="demo-user">Usuário: <strong>{userName}</strong></div>
			</aside>

			<section className="chat-panel">
				// Hamburger.
				<header className="chat-header">
					<button
						className="menu-button"
						aria-label="Abrir menu"
						onClick={
							() =>
								setShowSidebar(!showSidebar)
						}
					>☰</button>
					<div className="avatar">
						{userName.charAt(0)}
					</div>
					<div>
						// Selecionado? Mostra. Se não, pede pra selecionar.
						<strong>
							{group?.name || "Selecione um grupo"}
						</strong>
						<small>
							{conversation ? `# ${conversation.name}` : "Nenhuma conversa"}
						</small>
					</div>
					<span
						className={connected ? "connection online" : "connection offline"}
					>
						{connected ? "● online" : "● offline"}
					</span>
				</header>
				// Linha laranja.
				<div className="orange-line" />
				{
					notice &&
					<div className="notice" role="status">
						<span>
							{notice}
						</span>
						<button
							onClick={() => setNotice("")}
							aria-label="Fechar aviso"
						>×</button>
					</div>
				}
				// Daqui em diante, trivial.
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
