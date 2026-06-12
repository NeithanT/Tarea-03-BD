<script lang="ts">
	import { goto } from '$app/navigation';
	import {
		ApiError,
		planillasSemanales,
		planillasMensuales,
		deduccionesSemanales,
		asistenciasSemanales,
		deduccionesMensuales,
		regresarAdmin,
		logoutApi
	} from '$lib/api';
	import { authStore } from '$lib/auth';
	import type {
		AsistenciaDetalle,
		DeduccionDetalle,
		PlanillaMensual,
		PlanillaSemanal
	} from '$lib/types';
	import { onMount } from 'svelte';
	import Header from '../Header.svelte';

	//  Auth
	const auth = $derived($authStore);
	const username = $derived(auth?.user.username ?? '');
	const impersonando = $derived(auth?.user.impersonated_employee_id != null);

	//  Pestañas y selector de periodos
	let tab = $state<'semanal' | 'mensual'>('semanal');
	let limitSemanal = $state(10);
	let limitMensual = $state(6);

	//  Datos de planillas
	let semanales = $state<PlanillaSemanal[]>([]);
	let mensuales = $state<PlanillaMensual[]>([]);
	let loadingSemanal = $state(false);
	let loadingMensual = $state(false);
	let errorSemanal = $state('');
	let errorMensual = $state('');

	//  Modal de detalle
	let modalOpen = $state(false);
	let modalTitle = $state('');
	let modalKind = $state<'deducciones' | 'bruto'>('deducciones');
	let modalLoading = $state(false);
	let modalError = $state('');
	let modalDeducciones = $state<DeduccionDetalle[]>([]);
	let modalAsistencias = $state<AsistenciaDetalle[]>([]);

	onMount(() => {
		cargarSemanales();
		cargarMensuales();
	});

	async function cargarSemanales() {
		loadingSemanal = true;
		errorSemanal = '';
		try {
			semanales = await planillasSemanales(limitSemanal);
		} catch (e) {
			errorSemanal = e instanceof ApiError ? `Error ${e.status}` : 'Error al cargar planillas';
		} finally {
			loadingSemanal = false;
		}
	}

	async function cargarMensuales() {
		loadingMensual = true;
		errorMensual = '';
		try {
			mensuales = await planillasMensuales(limitMensual);
		} catch (e) {
			errorMensual = e instanceof ApiError ? `Error ${e.status}` : 'Error al cargar planillas';
		} finally {
			loadingMensual = false;
		}
	}

	//  Modales de detalle
	async function abrirDeduccionesSemanal(p: PlanillaSemanal) {
		abrirModal('deducciones', `Deducciones · Semana ${p.NumeroSemana}/${p.Ano}`);
		try {
			modalDeducciones = await deduccionesSemanales(p.id);
		} catch (e) {
			modalError = e instanceof ApiError ? `Error ${e.status}` : 'No se pudo cargar el detalle';
		} finally {
			modalLoading = false;
		}
	}

	async function abrirBrutoSemanal(p: PlanillaSemanal) {
		abrirModal('bruto', `Salario bruto · Semana ${p.NumeroSemana}/${p.Ano}`);
		try {
			modalAsistencias = await asistenciasSemanales(p.id);
		} catch (e) {
			modalError = e instanceof ApiError ? `Error ${e.status}` : 'No se pudo cargar el detalle';
		} finally {
			modalLoading = false;
		}
	}

	async function abrirDeduccionesMensual(p: PlanillaMensual) {
		abrirModal('deducciones', `Deducciones · ${nombreMes(p.Numero)} ${p.Ano}`);
		try {
			modalDeducciones = await deduccionesMensuales(p.id);
		} catch (e) {
			modalError = e instanceof ApiError ? `Error ${e.status}` : 'No se pudo cargar el detalle';
		} finally {
			modalLoading = false;
		}
	}

	function abrirModal(kind: 'deducciones' | 'bruto', title: string) {
		modalKind = kind;
		modalTitle = title;
		modalDeducciones = [];
		modalAsistencias = [];
		modalError = '';
		modalLoading = true;
		modalOpen = true;
	}

	function cerrarModal() {
		modalOpen = false;
	}

	//  Acciones de sesión
	async function handleLogout() {
		try {
			await logoutApi();
		} finally {
			authStore.logout();
			goto('/');
		}
	}

	async function handleRegresar() {
		try {
			await regresarAdmin();
		} catch {
			// aun si falla en el backend, limpiamos la sesión local
		}
		if (auth) {
			authStore.updateSession({
				token: auth.token,
				user: { ...auth.user, impersonated_employee_id: null }
			});
		}
		goto('/admin');
	}

	//  Helpers de formato
	function money(n: number | null | undefined): string {
		const v = Number(n ?? 0);
		return `₡${v.toLocaleString('es-CR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
	}

	function horas(n: number | null | undefined): string {
		return Number(n ?? 0).toLocaleString('es-CR', { maximumFractionDigits: 2 });
	}

	function nombreMes(numero: number): string {
		const meses = [
			'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
			'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
		];
		return meses[numero - 1] ?? `Mes ${numero}`;
	}
</script>

<svelte:head>
	<title>Mis planillas</title>
</svelte:head>

<div class="shell">
	<Header {username} onLogout={handleLogout} />

	<div class="content">
		<main class="panel">
			<div class="panel-inner">
				<div class="panel-top">
					<div>
						<h1 class="panel-title">Mis planillas</h1>
						<p class="panel-sub">Consulta tus planillas semanales y mensuales</p>
					</div>
					{#if impersonando}
						<button class="btn-secondary" onclick={handleRegresar}>
							← Regresar a administrador
						</button>
					{/if}
				</div>

				<!--  Pestañas  -->
				<div class="tabs">
					<button
						class="tab {tab === 'semanal' ? 'tab--active' : ''}"
						onclick={() => (tab = 'semanal')}
					>
						Planilla semanal
					</button>
					<button
						class="tab {tab === 'mensual' ? 'tab--active' : ''}"
						onclick={() => (tab = 'mensual')}
					>
						Planilla mensual
					</button>
				</div>

				{#if tab === 'semanal'}
					<!--  Selector de periodos  -->
					<div class="controls">
						<label class="control-label">
							Mostrar
							<select bind:value={limitSemanal} onchange={cargarSemanales} class="select">
								<option value={10}>últimas 10 semanas</option>
								<option value={25}>últimas 25 semanas</option>
								<option value={52}>últimas 52 semanas</option>
							</select>
						</label>
					</div>

					{#if loadingSemanal}
						<div class="state"><div class="spinner"></div><p>Cargando planillas…</p></div>
					{:else if errorSemanal}
						<p class="state state--error">{errorSemanal}</p>
					{:else if semanales.length === 0}
						<p class="state">No hay planillas semanales registradas.</p>
					{:else}
						<div class="table-wrap">
							<table class="grid">
								<thead>
									<tr>
										<th>Semana</th>
										<th class="num">Salario bruto</th>
										<th class="num">Deducciones</th>
										<th class="num">Salario neto</th>
										<th class="num">Horas ord.</th>
										<th class="num">Horas extra norm.</th>
										<th class="num">Horas extra dobles</th>
									</tr>
								</thead>
								<tbody>
									{#each semanales as p}
										<tr>
											<td class="td-strong">
												{p.NumeroSemana}/{p.Ano}
												<span class="td-range">{p.FechaInicio} – {p.FechaFin}</span>
											</td>
											<td class="num">
												<button class="link" onclick={() => abrirBrutoSemanal(p)}>
													{money(p.IngresoBruto)}
												</button>
											</td>
											<td class="num">
												<button class="link" onclick={() => abrirDeduccionesSemanal(p)}>
													{money(p.TotalDeducciones)}
												</button>
											</td>
											<td class="num td-strong">{money(p.IngresoNeto)}</td>
											<td class="num">{horas(p.HorasOrdinarias)}</td>
											<td class="num">{horas(p.HorasExtraNormales)}</td>
											<td class="num">{horas(p.HorasExtraDobles)}</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					{/if}
				{:else}
					<!--  Selector de periodos  -->
					<div class="controls">
						<label class="control-label">
							Mostrar
							<select bind:value={limitMensual} onchange={cargarMensuales} class="select">
								<option value={6}>últimos 6 meses</option>
								<option value={12}>últimos 12 meses</option>
								<option value={24}>últimos 24 meses</option>
							</select>
						</label>
					</div>

					{#if loadingMensual}
						<div class="state"><div class="spinner"></div><p>Cargando planillas…</p></div>
					{:else if errorMensual}
						<p class="state state--error">{errorMensual}</p>
					{:else if mensuales.length === 0}
						<p class="state">No hay planillas mensuales registradas.</p>
					{:else}
						<div class="table-wrap">
							<table class="grid">
								<thead>
									<tr>
										<th>Mes</th>
										<th class="num">Salario bruto</th>
										<th class="num">Deducciones</th>
										<th class="num">Salario neto</th>
									</tr>
								</thead>
								<tbody>
									{#each mensuales as p}
										<tr>
											<td class="td-strong">{nombreMes(p.Numero)} {p.Ano}</td>
											<td class="num">{money(p.IngresoBruto)}</td>
											<td class="num">
												<button class="link" onclick={() => abrirDeduccionesMensual(p)}>
													{money(p.TotalDeducciones)}
												</button>
											</td>
											<td class="num td-strong">{money(p.IngresoNeto)}</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					{/if}
				{/if}
			</div>
		</main>
	</div>
</div>

<!--  Modal de detalle  -->
{#if modalOpen}
	<div
		class="modal-backdrop"
		role="button"
		tabindex="0"
		onclick={cerrarModal}
		onkeydown={(e) => e.key === 'Escape' && cerrarModal()}
	>
		<div
			class="modal"
			role="dialog"
			aria-modal="true"
			tabindex="-1"
			onclick={(e) => e.stopPropagation()}
			onkeydown={() => {}}
		>
			<div class="modal-header">
				<h2 class="modal-title">{modalTitle}</h2>
				<button class="btn-ghost" onclick={cerrarModal} aria-label="Cerrar">
					<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
						stroke="currentColor" stroke-width="2" stroke-linecap="round"
						stroke-linejoin="round" aria-hidden="true">
						<line x1="18" y1="6" x2="6" y2="18" />
						<line x1="6" y1="6" x2="18" y2="18" />
					</svg>
				</button>
			</div>

			<div class="modal-body">
				{#if modalLoading}
					<div class="state"><div class="spinner"></div><p>Cargando detalle…</p></div>
				{:else if modalError}
					<p class="state state--error">{modalError}</p>
				{:else if modalKind === 'deducciones'}
					{#if modalDeducciones.length === 0}
						<p class="state">Sin deducciones para este periodo.</p>
					{:else}
						<table class="grid">
							<thead>
								<tr>
									<th>Deducción</th>
									<th class="num">Porcentaje</th>
									<th class="num">Monto</th>
								</tr>
							</thead>
							<tbody>
								{#each modalDeducciones as d}
									<tr>
										<td class="td-strong">{d.NombreDeduccion}</td>
										<td class="num">{d.Porcentual && d.Porcentaje != null ? `${(Number(d.Porcentaje) * 100).toLocaleString('es-CR', { maximumFractionDigits: 2 })}%` : '—'}</td>
										<td class="num">{money(d.Monto)}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					{/if}
				{:else if modalAsistencias.length === 0}
					<p class="state">Sin asistencias registradas para esta semana.</p>
				{:else}
					<table class="grid">
						<thead>
							<tr>
								<th>Fecha</th>
								<th>Entrada</th>
								<th>Salida</th>
								<th class="num">H. ord.</th>
								<th class="num">Monto ord.</th>
								<th class="num">H. ext. norm.</th>
								<th class="num">Monto ext. norm.</th>
								<th class="num">H. ext. dobles</th>
								<th class="num">Monto ext. dobles</th>
							</tr>
						</thead>
						<tbody>
							{#each modalAsistencias as a}
								<tr>
									<td class="td-strong">{a.Fecha}</td>
									<td>{a.HoraEntrada ?? '—'}</td>
									<td>{a.HoraSalida ?? '—'}</td>
									<td class="num">{horas(a.HorasOrdinarias)}</td>
									<td class="num">{money(a.MontoOrdinario)}</td>
									<td class="num">{horas(a.HorasExtraNormales)}</td>
									<td class="num">{money(a.MontoExtraNormal)}</td>
									<td class="num">{horas(a.HorasExtraDobles)}</td>
									<td class="num">{money(a.MontoExtraDoble)}</td>
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
	h1, h2, p {
		font-size: inherit;
		font-weight: inherit;
		text-align: inherit;
		line-height: inherit;
	}

	/* Shell */
	.shell {
		display: flex;
		flex-direction: column;
		height: 100vh;
		width: 100%;
		background: #f9fafb;
		font-family: inherit;
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
	}

	.content {
		width: 100%;
		height: 100%;
		display: flex;
		flex: 1;
		overflow: hidden;
	}

	.panel {
		flex: 1;
		overflow-y: auto;
	}

	.panel-inner {
		padding: 1.75rem 2rem;
		max-width: 64rem;
		margin: 0 auto;
		width: 100%;
		box-sizing: border-box;
	}

	.panel-top {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		gap: 1rem;
		margin-bottom: 1.25rem;
	}

	.panel-title {
		font-size: 1.25rem;
		font-weight: 600;
		color: #111827;
		margin: 0 0 0.25rem;
	}

	.panel-sub {
		font-size: 0.8125rem;
		color: #9ca3af;
		margin: 0;
	}

	/* Tabs */
	.tabs {
		display: flex;
		gap: 0.25rem;
		border-bottom: 1px solid #e5e7eb;
		margin-bottom: 1.25rem;
	}

	.tab {
		padding: 0.625rem 1rem;
		font-size: 0.875rem;
		font-weight: 500;
		color: #6b7280;
		background: transparent;
		border: none;
		border-bottom: 2px solid transparent;
		margin-bottom: -1px;
		cursor: pointer;
		font-family: inherit;
		transition: color 0.15s, border-color 0.15s;
	}

	.tab:hover {
		color: #111827;
	}

	.tab--active {
		color: #1d4ed8;
		border-bottom-color: #2563eb;
	}

	/* Controls */
	.controls {
		display: flex;
		justify-content: flex-end;
		margin-bottom: 0.875rem;
	}

	.control-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.8125rem;
		color: #6b7280;
	}

	.select {
		padding: 0.375rem 0.625rem;
		font-size: 0.8125rem;
		border: 1px solid #d1d5db;
		border-radius: 0.5rem;
		background: #fff;
		color: #111827;
		cursor: pointer;
		font-family: inherit;
	}

	/* Tables / grids */
	.table-wrap {
		overflow-x: auto;
		border: 1px solid #e5e7eb;
		border-radius: 0.75rem;
		background: #fff;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
	}

	.grid {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.8125rem;
	}

	.grid th {
		text-align: left;
		padding: 0.5rem 0.875rem;
		font-size: 0.7rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #6b7280;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.grid td {
		padding: 0.5rem 0.875rem;
		color: #374151;
		border-bottom: 1px solid #f3f4f6;
		font-variant-numeric: tabular-nums;
		white-space: nowrap;
	}

	.grid tr:last-child td {
		border-bottom: none;
	}

	.grid .num {
		text-align: right;
	}

	.td-strong {
		font-weight: 600;
		color: #111827;
	}

	.td-range {
		display: block;
		font-size: 0.7rem;
		font-weight: 400;
		color: #9ca3af;
	}

	/* Clickable amount */
	.link {
		background: transparent;
		border: none;
		padding: 0;
		font: inherit;
		font-variant-numeric: tabular-nums;
		color: #2563eb;
		font-weight: 600;
		cursor: pointer;
		text-decoration: underline;
		text-underline-offset: 2px;
	}

	.link:hover {
		color: #1d4ed8;
	}

	/* States */
	.state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.625rem;
		padding: 2rem 1rem;
		font-size: 0.8125rem;
		color: #9ca3af;
	}

	.state--error {
		color: #ef4444;
	}

	/* Buttons */
	.btn-secondary {
		padding: 0.45rem 0.875rem;
		font-size: 0.8125rem;
		font-weight: 600;
		color: #374151;
		background: #fff;
		border: 1px solid #d1d5db;
		border-radius: 0.5rem;
		cursor: pointer;
		font-family: inherit;
		flex-shrink: 0;
		transition: background 0.1s, border-color 0.1s;
	}

	.btn-secondary:hover {
		background: #f3f4f6;
	}

	.btn-ghost {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 2rem;
		height: 2rem;
		border: none;
		background: transparent;
		border-radius: 0.375rem;
		cursor: pointer;
		color: #9ca3af;
		transition: background 0.1s, color 0.1s;
		flex-shrink: 0;
	}

	.btn-ghost:hover {
		background: #f3f4f6;
		color: #374151;
	}

	.btn-ghost svg {
		width: 1rem;
		height: 1rem;
	}

	/* Spinner */
	.spinner {
		width: 1.5rem;
		height: 1.5rem;
		border: 2px solid #e5e7eb;
		border-top-color: #2563eb;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Modal */
	.modal-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(17, 24, 39, 0.45);
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1.5rem;
		z-index: 50;
	}

	.modal {
		background: #fff;
		border-radius: 0.75rem;
		box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2);
		width: 100%;
		max-width: 52rem;
		max-height: 85vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.25rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-title {
		font-size: 0.9375rem;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.modal-body {
		padding: 1rem 1.25rem 1.25rem;
		overflow: auto;
	}
</style>
