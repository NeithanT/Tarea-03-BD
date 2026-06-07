import { browser } from '$app/environment';
import { writable } from 'svelte/store';
import type { AuthState } from '$lib/types';

const STORAGE_KEY = 'auth';

function loadFromStorage(): AuthState | null {
	if (!browser) return null;
	try {
		const raw = localStorage.getItem(STORAGE_KEY);
		return raw ? (JSON.parse(raw) as AuthState) : null;
	} catch {
		return null;
	}
}

function createAuthStore() {
	const { subscribe, set, update } = writable<AuthState | null>(loadFromStorage());

	return {
		subscribe,

		login(state: AuthState) {
			if (browser) localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
			set(state);
		},

		logout() {
			if (browser) localStorage.removeItem(STORAGE_KEY);
			set(null);
		},

		updateSession(state: AuthState) {
			if (browser) localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
			set(state);
		},

		getToken(): string | null {
			let token: string | null = null;
			// get() síncrono usando subscribe
			const unsub = subscribe((s) => (token = s?.token ?? null));
			unsub();
			return token;
		}
	};
}

export const authStore = createAuthStore();
