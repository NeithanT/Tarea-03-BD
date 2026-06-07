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
	<link
		href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600;700&display=swap"
		rel="stylesheet"
	/>
</svelte:head>

<div class="page">
	<div class="login_form">
		<form onsubmit={handleSubmit}>
			<h3>Sistema de Planillas</h3>

			<div class="input_box">
				<label for="username">Usuario</label>
				<input
					id="username"
					type="text"
					bind:value={username}
					placeholder="Ingresa tu usuario"
					autocomplete="username"
					required
					disabled={loading}
				/>
			</div>

			<div class="input_box">
				<label for="password">Contraseña</label>
				<input
					id="password"
					type="password"
					bind:value={password}
					placeholder="Ingresa tu contraseña"
					autocomplete="current-password"
					required
					disabled={loading}
				/>
			</div>

			{#if error}
				<p class="error">{error}</p>
			{/if}

			<button type="submit" disabled={loading}>
				{loading ? 'Ingresando…' : 'Ingresar'}
			</button>
		</form>
	</div>
</div>

<style>
	:global(*) {
		margin: 0;
		padding: 0;
		box-sizing: border-box;
		font-family: 'Montserrat', sans-serif;
	}

	.page {
		width: 100%;
		min-height: 100vh;
		padding: 0 10px;
		display: flex;
		justify-content: center;
		align-items: center;
	}

	.login_form {
		width: 100%;
		max-width: 435px;
		background: #fff;
		border-radius: 6px;
		padding: 41px 30px;
		box-shadow: 0 10px 20px rgba(0, 0, 0, 0.15);
	}

	.login_form h3 {
		font-size: 20px;
		text-align: center;
		margin-bottom: 34px;
		color: #001a4d;
	}

	.input_box label {
		display: block;
		font-weight: 500;
		margin-bottom: 8px;
		color: #001a4d;
	}

	.input_box input {
		width: 100%;
		height: 57px;
		border: 1px solid #b3d4ff;
		border-radius: 5px;
		outline: none;
		background: #f0f7ff;
		font-size: 17px;
		padding: 0 20px;
		margin-bottom: 25px;
		transition: 0.2s ease;
		font-family: 'Montserrat', sans-serif;
	}

	.input_box input:focus {
		border-color: #0070f3;
	}

	.input_box input:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.error {
		color: #dc2626;
		font-size: 0.875rem;
		font-weight: 500;
		text-align: center;
		margin-bottom: 16px;
		margin-top: -10px;
	}

	button {
		width: 100%;
		height: 56px;
		border-radius: 5px;
		border: none;
		outline: none;
		background: #0070f3;
		color: #fff;
		font-size: 18px;
		font-weight: 500;
		font-family: 'Montserrat', sans-serif;
		text-transform: uppercase;
		cursor: pointer;
		margin-bottom: 28px;
		transition: 0.3s ease;
	}

	button:hover:not(:disabled) {
		background: #0057cc;
	}

	button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>
