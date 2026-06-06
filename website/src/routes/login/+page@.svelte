<script lang="ts">
	import { goto } from '$app/navigation';
	import { loginApi } from '$lib/api';
	import { authStore } from '$lib/auth';
	import { ApiError } from '$lib/api';

	let username = $state('');
	let password = $state('');
	let error = $state('');
	let loading = $state(false);

	async function handleSubmit(e: SubmitEvent) {
		e.preventDefault();
		error = '';
		loading = true;

		try {
			const authState = await loginApi(username, password);
			authStore.login(authState);

			if (authState.user.role.toLowerCase() === 'administrador') {
				goto('/admin');
			} else {
				goto('/empleado');
			}
		} catch (err) {
			if (err instanceof ApiError && err.status === 401) {
				error = 'Usuario o contraseña incorrectos.';
			} else {
				error = 'Error al conectar con el servidor.';
			}
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>Iniciar sesión</title>
</svelte:head>

<div class="flex min-h-screen items-center justify-center bg-gray-50 px-4">
	<div class="w-full max-w-sm">
		<div class="mb-8 text-center">
			<h1 class="text-2xl font-bold text-gray-900">Sistema de Planillas</h1>
			<p class="mt-1 text-sm text-gray-500">Ingresa tus credenciales para continuar</p>
		</div>

		<form
			onsubmit={handleSubmit}
			class="rounded-xl border border-gray-200 bg-white px-8 py-8 shadow-sm"
		>
			<div class="mb-4">
				<label for="username" class="mb-1 block text-sm font-medium text-gray-700">
					Usuario
				</label>
				<input
					id="username"
					type="text"
					bind:value={username}
					autocomplete="username"
					required
					disabled={loading}
					class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-none disabled:bg-gray-100"
					placeholder="admin"
				/>
			</div>

			<div class="mb-6">
				<label for="password" class="mb-1 block text-sm font-medium text-gray-700">
					Contraseña
				</label>
				<input
					id="password"
					type="password"
					bind:value={password}
					autocomplete="current-password"
					required
					disabled={loading}
					class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-none disabled:bg-gray-100"
					placeholder="••••••••"
				/>
			</div>

			{#if error}
				<p class="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">{error}</p>
			{/if}

			<button
				type="submit"
				disabled={loading}
				class="w-full rounded-lg bg-blue-600 py-2 text-sm font-semibold text-white transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60"
			>
				{loading ? 'Ingresando…' : 'Ingresar'}
			</button>
		</form>
	</div>
</div>
