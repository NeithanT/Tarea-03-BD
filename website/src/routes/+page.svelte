<script lang="ts">
	import { login } from '../api';

	let username = '';
	let password = '';
	let message = '';
	let messageType: 'success' | 'error' | '' = '';
	let loading = false;

	const handleSubmit = async () => {
		loading = true;
		message = '';
		messageType = '';

		try {
			const result = await login({ username, password });
			message = result.message;
			messageType = result.success ? 'success' : 'error';
		} catch (error) {
			message = error instanceof Error ? error.message : 'Unexpected error';
			messageType = 'error';
		} finally {
			loading = false;
		}
	};
</script>

<svelte:head>
	<title>Login</title>
	<meta name="description" content="Login page" />
</svelte:head>

<section>
	<div class="login-card">
		<h1>Login</h1>
		<form on:submit|preventDefault={handleSubmit}>
			<label for="username">Username</label>
			<input id="username" type="username" bind:value={username} required />

			<label for="password">Password</label>
			<input id="password" type="password" bind:value={password} required />

			<button type="submit" disabled={loading}>
				{#if loading}
					Cargando ...
				{:else}
					Iniciar Sesión
				{/if}
			</button>
		</form>

		{#if message}
			<p class="message {messageType}">{message}</p>
		{/if}
	</div>
</section>

<style>
	section {
		display: flex;
		justify-content: center;
		align-items: center;
		min-height: 100vh;
		min-width: 100vw;
		background: #eef2f7;
	}

	.login-card {
		width: 100%;
		max-width: 600px;
		padding: 2rem;
		border-radius: 16px;
		background: white;
		box-shadow: 0 20px 50px rgba(0, 0, 0, 0.08);
	}

	h1 {
		margin: 0 0 1.5rem;
		font-size: 1.75rem;
		text-align: center;
	}

	label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 600;
	}

	input {
		width: 95%;
		padding: 0.9rem 1rem;
		margin-bottom: 1rem;
		border: 1px solid #cbd5e1;
		border-radius: 12px;
		font-size: 1rem;
		outline: none;
	}

	input:focus {
		border-color: #6366f1;
		box-shadow: inset 0 0 0 1px rgba(99, 102, 241, 0.2);
	}

	button {
		width: 100%;
		padding: 1rem;
		border: none;
		border-radius: 12px;
		background: #4f46e5;
		color: white;
		font-size: 1rem;
		font-weight: 700;
		cursor: pointer;
	}

	button:hover {
		background: #4338ca;
	}

	.message {
		margin-top: 1rem;
		padding: 0.85rem 1rem;
		border-radius: 12px;
		text-align: center;
		font-weight: 600;
	}

	.message.success {
		background: #ddf7e2;
		color: #166534;
	}

	.message.error {
		background: #fee2e2;
		color: #991b1b;
	}
</style>
