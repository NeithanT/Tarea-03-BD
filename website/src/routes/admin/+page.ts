import { browser } from '$app/environment';
import { redirect } from '@sveltejs/kit';
import { get } from 'svelte/store';
import { authStore } from '$lib/auth';

export const ssr = false;

export function load() {
	if (!browser) return {};

	const auth = get(authStore);
	if (!auth) throw redirect(302, '/');
	if (auth.user.role.toLowerCase() !== 'administrador') throw redirect(302, '/');

	return {};
}
