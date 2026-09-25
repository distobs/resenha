const BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:8080/api";

async function request(path, userId, options = {}) {
  const response = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: { "Content-Type": "application/json", "X-User-Id": userId, ...(options.headers || {}) },
  });
  if (!response.ok) throw new Error(`Erro HTTP ${response.status}`);
  return response.status === 204 ? null : response.json();
}

export const getGroups = (userId) => request("/groups", userId);
export const getConversations = (groupId, userId) => request(`/groups/${groupId}/conversations`, userId);
export const getMessages = (conversationId, userId) => request(`/conversations/${conversationId}/messages`, userId);
export const createGroup = (userId, data) => request("/groups", userId, { method: "POST", body: JSON.stringify(data) });
export const createConversation = (groupId, userId, data) => request(`/groups/${groupId}/conversations`, userId, { method: "POST", body: JSON.stringify(data) });
