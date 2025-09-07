import axios from "axios";

const BASE = (import.meta as any).env?.VITE_API_URL || "http://localhost:8000";

let token: string | null = null;
export function setToken(t: string) { token = t; }

export async function login(username: string, password: string) {
  const { data } = await axios.post(`${BASE}/login`, { username, password });
  token = data.access_token;
  return data;
}

function auth() { return token ? { Authorization: `Bearer ${token}` } : {}; }

export async function chat(messages: any[]) {
  const { data } = await axios.post(`${BASE}/chat`, { messages }, { headers: auth() });
  return data.content;
}

export async function chatReasoned(messages: any[], level: 'low'|'medium'|'high'='medium') {
  const { data } = await axios.post(`${BASE}/chat/reasoned?reasoning_level=${level}`, { messages }, { headers: auth() });
  return data.content;
}

export async function ragIngest(file: File) {
  const fd = new FormData();
  fd.append("file", file);
  const { data } = await axios.post(`${BASE}/rag/ingest`, fd, { headers: auth() });
  return data;
}

export async function ragQuery(query: string) {
  const { data } = await axios.post(`${BASE}/rag/query`, { query, k: 5 }, { headers: auth() });
  return data;
}

export async function uploadBib(file: File) {
  const fd = new FormData();
  fd.append("file", file);
  const { data } = await axios.post(`${BASE}/refs/upload`, fd, { headers: auth() });
  return data;
}

export async function cite(keys: string[]) {
  const { data } = await axios.post(`${BASE}/refs/cite`, { keys }, { headers: auth() });
  return data.bibliography as string;
}
