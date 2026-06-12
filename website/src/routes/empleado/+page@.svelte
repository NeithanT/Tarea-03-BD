<script lang="ts">
	import { goto } from '$app/navigation';
	import {
		planillasSemanales,
		deduccionesSemanales,
		asistenciasSemanales,
		regresarAdmin,
		logoutApi
	} from '$lib/api';
	import { authStore } from '$lib/auth';
	import { ApiError } from '$lib/api';
	import type { PlanillaSemanal, DeduccionSemanal, AsistenciaSemanal } from '$lib/types';
	import { onMount } from 'svelte';
	import Header from '../Header.svelte';

	// Estado principal
	let planillas = $state<PlanillaSemanal[]>([]);
	let loading = $state(true);
	let error = $state('');

	// Modal deducciones
	let modalDeducciones = $state<{ planillaId: number; titulo: string } | null>(null);
	let deducciones = $state<DeduccionSemanal[]>([]);
	let loadingDed = $state(false);
	let errorDed = $state('');

	// Modal asistencias
	let modalAsistencias = $state<{ planillaId: number; titulo: string } | null>(null);
	let asistencias = $state<AsistenciaSemanal[]>([]);
	let loadingAsist = $state(false);
	let errorAsist = $state('');

	// Auth
	const auth = $derived($authStore);
	const username = $derived(auth?.user.username ?? '');
	const esImpersonacion = $derived(
		auth?.user.impersonated_employee_id != null
	);

	onMount(() => {
		cargarPlanillas();
	});

	async function cargarPlanillas() {
		loading = true;
		error = '';
		try {
			planillas = await planillasSemanales(20);
		} catch (e) {
			error = e instanceof ApiError ? `Error ${e.status}` : 'No se pudieron cargar las planillas.';
		} finally {
			loading = false;
		}
	}

	async function abrirDeducciones(planilla: PlanillaSemanal) {
		modalDeducciones = {
			planillaId: planilla.id,
			titulo: `Deducciones — ${planilla.FechaInicio} al ${planilla.FechaFin}`
		};
		deducciones = [];
		errorDed = '';
		loadingDed = true;
		try {
			deducciones = await deduccionesSemanales(planilla.id);
		} catch (e) {
			errorDed = e instanceof ApiError ? `Error ${e.status}` : 'No se pudieron cargar las deducciones.';
		} finally {
			loadingDed = false;
		}
	}

	async function abrirAsistencias(planilla: PlanillaSemanal) {
		modalAsistencias = {
			planillaId: planilla.id,
			titulo: `Asistencias — ${planilla.FechaInicio} al ${planilla.FechaFin}`
		};
		asistencias = [];
		errorAsist = '';
		loadingAsist = true;
		try {
			asistencias = await asistenciasSemanales(planilla.id);
		} catch (e) {
			errorAsist = e instanceof ApiError ? `Error ${e.status}` : 'No se pudieron cargar las asistencias.';
		} finally {
			loadingAsist = false;
		}
	}

	function cerrarModales() {
		modalDeducciones = null;
		modalAsistencias = null;
	}

	async function handleRegresarAdmin() {
		try {
			await regresarAdmin();
			authStore.updateSession({ token: authStore.getToken()!, user: { ...auth!.user, impersonated_employee_id: null } });
			goto('/admin');
		} catch {
			// si falla, forzar logout
			authStore.logout();
			goto('/');
		}
	}

	async function handleLogout() {
		try {
			await logoutApi();
		} finally {
			authStore.logout();
			goto('/');
		}
	}

	function fmt(n: number): string {
		return n.toLocaleString('es-CR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
	}

	function fmtH(n: number): string {
		return n % 1 === 0 ? String(n) : n.toFixed(1);
	}
</script>

<svelte:head>
	<title>Portal del Empleado</title>
</svelte:head>

<div class="shell">
	<header class="hdr">
		<span class="brand">Sistema de Planillas</span>
		<div class="hdr-actions">
			<span class="hdr-user">{username}</span>
			{#if esImpersonacion}
				<button class="btn-secondary" onclick={handleRegresarAdmin}>Regresar a Admin</button>
			{/if}
			<button class="btn-ghost-hdr" onclick={handleLogout}>Cerrar sesión</button>
		</div>
	</header>

	<main class="content">
		<div class="section-card">
			<h2 class="section-title">Planillas Semanales</h2>

			{#if loading}
				<div class="state-row">
					<div class="spinner"></div>
					<span>Cargando…</span>
				</div>
			{:else if error}
				<p class="alert alert--error">{error}</p>
			{:else if planillas.length === 0}
				<p class="state-empty">No hay planillas registradas.</p>
			{:else}
				<div class="table-wrap">
					<table class="data-table">
						<thead>
							<tr>
								<th>Período</th>
								<th class="th-num">Salario bruto</th>
								<th class="th-num">Total deducciones</th>
								<th class="th-num">Salario neto</th>
								<th class="th-num">H. ord.</th>
								<th class="th-num">H. extra</th>
								<th class="th-num">H. extra doble</th>
							</tr>
						</thead>
						<tbody>
							{#each planillas as p}
								<tr>
									<td class="td-periodo">{p.FechaInicio} – {p.FechaFin}</td>
									<td class="td-num">
										<button class="cell-link" onclick={() => abrirAsistencias(p)}>
											₡{fmt(p.SalarioBruto)}
										</button>
									</td>
									<td class="td-num">
										<button class="cell-link cell-link--red" onclick={() => abrirDeducciones(p)}>
											₡{fmt(p.TotalDeducciones)}
										</button>
									</td>
									<td class="td-num td-neto">₡{fmt(p.SalarioNeto)}</td>
									<td class="td-num">{fmtH(p.HorasOrdinarias)}</td>
									<td class="td-num">{fmtH(p.HorasExtra)}</td>
									<td class="td-num">{fmtH(p.HorasExtraDoble)}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	</main>
</div>

<!-- Modal Deducciones -->
{#if modalDeducciones}
	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
	<div class="overlay" onclick={cerrarModales}>
		<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
		<div class="modal" onclick={(e) => e.stopPropagation()}>
			<div class="modal-header">
				<h3>{modalDeducciones.titulo}</h3>
				<button class="modal-close" onclick={cerrarModales} aria-label="Cerrar">✕</button>
			</div>
			<div class="modal-body">
				{#if loadingDed}
					<div class="state-row"><div class="spinner"></div><span>Cargando…</span></div>
				{:else if errorDed}
					<p class="alert alert--error">{errorDed}</p>
				{:else if deducciones.length === 0}
					<p class="state-empty">Sin deducciones en este período.</p>
				{:else}
					<table class="data-table">
						<thead>
							<tr>
								<th>Deducción</th>
								<th class="th-num">Porcentaje</th>
								<th class="th-num">Monto</th>
							</tr>
						</thead>
						<tbody>
							{#each deducciones as d}
								<tr>
									<td>{d.Nombre}</td>
									<td class="td-num">
										{d.Porcentaje != null ? `${d.Porcentaje}%` : '—'}
									</td>
									<td class="td-num">₡{fmt(d.Monto)}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				{/if}
			</div>
		</div>
	</div>
{/if}

<!-- Modal Asistencias -->
{#if modalAsistencias}
	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
	<div class="overlay" onclick={cerrarModales}>
		<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
		<div class="modal modal--wide" onclick={(e) => e.stopPropagation()}>
			<div class="modal-header">
				<h3>{modalAsistencias.titulo}</h3>
				<button class="modal-close" onclick={cerrarModales} aria-label="Cerrar">✕</button>
			</div>
			<div class="modal-body">
				{#if loadingAsist}
					<div class="state-row"><div class="spinner"></div><span>Cargando…</span></div>
				{:else if errorAsist}
					<p class="alert alert--error">{errorAsist}</p>
				{:else if asistencias.length === 0}
					<p class="state-empty">Sin asistencias en este período.</p>
				{:else}
					<table class="data-table">
						<thead>
							<tr>
								<th>Fecha</th>
								<th class="th-num">Entrada</th>
								<th class="th-num">Salida</th>
								<th class="th-num">H. ord.</th>
								<th class="th-num">Monto ord.</th>
								<th class="th-num">H. extra</th>
								<th class="th-num">Monto extra</th>
								<th class="th-num">H. extra doble</th>
								<th class="th-num">Monto extra doble</th>
							</tr>
						</thead>
						<tbody>
							{#each asistencias as a}
								<tr>
									<td class="td-periodo">{a.Fecha}</td>
									<td class="td-num">{a.HoraEntrada ?? '—'}</td>
									<td class="td-num">{a.HoraSalida ?? '—'}</td>
									<td class="td-num">{fmtH(a.HorasOrdinarias)}</td>
									<td class="td-num">₡{fmt(a.MontoOrdinario)}</td>
									<td class="td-num">{fmtH(a.HorasExtra)}</td>
									<td class="td-num">₡{fmt(a.MontoExtra)}</td>
									<td class="td-num">{fmtH(a.HorasExtraDoble)}</td>
									<td class="td-num">₡{fmt(a.MontoExtraDoble)}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	:global(*, *::before, *::after) {
		box-sizing: border-box;
		margin: 0;
		padding: 0;
		font-family: 'Montserrat', 'Segoe UI', Arial, sans-serif;
	}

	/* Shell */
	.shell {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		background: #f3f4f6;
	}

	/* Header */
	.hdr {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0 1.5rem;
		height: 3.25rem;
		background: #fff;
		border-bottom: 1px solid #e5e7eb;
		box-shadow: 0 1px 2px rgba(0,0,0,0.04);
		flex-shrink: 0;
	}

	.brand {
		font-size: 0.9375rem;
		font-weight: 600;
		color: #111827;
	}

	.hdr-actions {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.hdr-user {
		font-size: 0.8125rem;
		color: #6b7280;
	}

	/* Content */
	.content {
		flex: 1;
		padding: 1.75rem 1.5rem;
		max-width: 1200px;
		width: 100%;
		margin: 0 auto;
	}

	/* Section card */
	.section-card {
		background: #fff;
		border: 1px solid #e5e7eb;
		border-radius: 0.75rem;
		box-shadow: 0 1px 3px rgba(0,0,0,0.04);
		overflow: hidden;
	}

	.section-title {
		font-size: 0.9375rem;
		font-weight: 600;
		color: #111827;
		padding: 1.25rem 1.5rem 1rem;
		border-bottom: 1px solid #f3f4f6;
	}

	/* Table */
	.table-wrap {
		overflow-x: auto;
	}

	.data-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.8125rem;
	}

	.data-table th {
		text-align: left;
		padding: 0.625rem 1rem;
		font-size: 0.7rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #6b7280;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.th-num {
		text-align: right;
	}

	.data-table td {
		padding: 0.625rem 1rem;
		color: #374151;
		border-bottom: 1px solid #f3f4f6;
		white-space: nowrap;
	}

	.data-table tr:last-child td {
		border-bottom: none;
	}

	.data-table tr:hover td {
		background: #f9fafb;
	}

	.td-periodo {
		font-variant-numeric: tabular-nums;
		color: #6b7280;
	}

	.td-num {
		text-align: right;
		font-variant-numeric: tabular-nums;
	}

	.td-neto {
		font-weight: 600;
		color: #111827;
	}

	/* Clickable cells */
	.cell-link {
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
		font: inherit;
		color: #2563eb;
		font-weight: 500;
		text-decoration: underline;
		text-underline-offset: 2px;
		font-variant-numeric: tabular-nums;
	}

	.cell-link:hover {
		color: #1d4ed8;
	}

	.cell-link--red {
		color: #dc2626;
	}

	.cell-link--red:hover {
		color: #b91c1c;
	}

	/* Buttons */
	.btn-secondary {
		padding: 0.375rem 0.875rem;
		font-size: 0.8125rem;
		font-weight: 500;
		color: #fff;
		background: #2563eb;
		border: none;
		border-radius: 0.5rem;
		cursor: pointer;
		font-family: inherit;
		transition: background 0.15s;
	}

	.btn-secondary:hover {
		background: #1d4ed8;
	}

	.btn-ghost-hdr {
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

	.btn-ghost-hdr:hover {
		background: #f9fafb;
	}

	/* States */
	.state-row {
		display: flex;
		align-items: center;
		gap: 0.625rem;
		padding: 1.5rem;
		font-size: 0.875rem;
		color: #6b7280;
	}

	.state-empty {
		padding: 1.5rem;
		font-size: 0.875rem;
		color: #9ca3af;
		text-align: center;
	}

	.alert {
		padding: 0.75rem 1rem;
		border-radius: 0.5rem;
		font-size: 0.8125rem;
		margin: 1rem 1.5rem;
	}

	.alert--error {
		background: #fef2f2;
		color: #dc2626;
	}

	/* Spinner */
	.spinner {
		width: 1.25rem;
		height: 1.25rem;
		border: 2px solid #e5e7eb;
		border-top-color: #2563eb;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		flex-shrink: 0;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Modal overlay */
	.overlay {
		position: fixed;
		inset: 0;
		background: rgba(0,0,0,0.4);
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		z-index: 100;
	}

	.modal {
		background: #fff;
		border-radius: 0.75rem;
		box-shadow: 0 20px 60px rgba(0,0,0,0.2);
		width: 100%;
		max-width: 480px;
		max-height: 85vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.modal--wide {
		max-width: 900px;
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.25rem;
		border-bottom: 1px solid #e5e7eb;
		flex-shrink: 0;
	}

	.modal-header h3 {
		font-size: 0.9375rem;
		font-weight: 600;
		color: #111827;
	}

	.modal-close {
		background: none;
		border: none;
		cursor: pointer;
		font-size: 1rem;
		color: #9ca3af;
		padding: 0.25rem;
		border-radius: 0.25rem;
		line-height: 1;
		transition: color 0.1s;
	}

	.modal-close:hover {
		color: #374151;
	}

	.modal-body {
		overflow-y: auto;
		flex: 1;
	}
</style>
