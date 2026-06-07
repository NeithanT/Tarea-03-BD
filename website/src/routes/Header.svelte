<script lang="ts">
	interface Props {
		username: string;
		onLogout: () => void;
	}

	let { username, onLogout }: Props = $props();
</script>

<header>
	<div class="brand">
		<span class="brand-name">Sistema de Planillnas</span>
	</div>

	<div class="actions">
		<span class="username">{username}</span>
		<button class="logout-btn" onclick={onLogout}>Cerrar sesión</button>
	</div>
</header>

<style>
	header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0 1.25rem;
		height: 3.25rem;
		background: #fff;
		border-bottom: 1px solid #e5e7eb;
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
		flex-shrink: 0;
	}

	.brand {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
	}


	.brand-name {
		font-weight: 600;
		color: #111827;
	}

	.actions {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.username {
		font-size: 0.8125rem;
		color: #6b7280;
	}

	.logout-btn {
		padding: 0.375rem 0.875rem;
		font-size: 0.8125rem;
		font-weight: 500;
		color: #374151;
		background: #fff;
		border: 1px solid #d1d5db;
		border-radius: 0.5rem;
		cursor: pointer;
		font-family: inherit;
		transition: background 0.1s;
	}

	.logout-btn:hover {
		background: #f9fafb;
	}
</style>
