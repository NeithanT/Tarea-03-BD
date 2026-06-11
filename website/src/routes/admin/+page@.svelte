<script lang="ts">
	import { goto } from '$app/navigation';
	import {
		listarEmpleados,
		buscarEmpleados,
		obtenerEmpleado,
		obtenerHorarioEmpleado,
		editarEmpleado,
		listarPuestos,
		impersonar,
		logoutApi
	} from '$lib/api';
	import { authStore } from '$lib/auth';
	import { ApiError } from '$lib/api';
	import type { Empleado, EmpleadoDetalle, HorarioDia, Puesto } from '$lib/types';
	import { onMount } from 'svelte';
	import Header from '../Header.svelte';

	// ── Estado de la lista ───────────────────────────────────────────────────
	let empleados = $state<Empleado[]>([]);
	let loadingLista = $state(true);
	let errorLista = $state('');
	let filtro = $state('');
	let debounceTimer: ReturnType<typeof setTimeout>;

	// ── Estado del panel de edición ──────────────────────────────────────────
	let seleccionado = $state<EmpleadoDetalle | null>(null);
	let puestos = $state<Puesto[]>([]);
	let loadingDetalle = $state(false);
	let loadingGuardar = $state(false);
	let loadingImpersonar = $state(false);
	let errorForm = $state('');
	let mensajeOk = $state('');

	// ── Estado del horario ───────────────────────────────────────────────────
	let horario = $state<HorarioDia[]>([]);
	let loadingHorario = $state(false);
	let errorHorario = $state('');

	// Campos del formulario (sincronizados con `seleccionado`)
	let fNombre = $state('');
	let fApellido = $state('');
	let fFechaIngreso = $state('');
	let fFechaNacimiento = $state('');
	let fPuestoId = $state(0);
	let fActivo = $state(true);

	// ── Auth ─────────────────────────────────────────────────────────────────
	const auth = $derived($authStore);
	const username = $derived(auth?.user.username ?? '');

	// ── Carga inicial ─────────────────────────────────────────────────────────
	onMount(() => {
		cargarEmpleados();
	});

	async function cargarEmpleados() {
		loadingLista = true;
		errorLista = '';
		try {
			empleados = await listarEmpleados();
		} catch (e) {
			errorLista = e instanceof ApiError ? `Error ${e.status}` : 'Error al cargar empleados';
		} finally {
			loadingLista = false;
		}
	}

	// ── Búsqueda con debounce ─────────────────────────────────────────────────
	function onFiltroInput() {
		clearTimeout(debounceTimer);
		debounceTimer = setTimeout(async () => {
			loadingLista = true;
			errorLista = '';
			try {
				empleados = filtro.trim()
					? await buscarEmpleados(filtro.trim())
					: await listarEmpleados();
			} catch (e) {
				errorLista = e instanceof ApiError ? `Error ${e.status}` : 'Error al buscar';
			} finally {
				loadingLista = false;
			}
		}, 300);
	}

	// ── Seleccionar empleado ──────────────────────────────────────────────────
	async function seleccionar(id: number) {
		if (loadingDetalle) return;
		errorForm = '';
		mensajeOk = '';
		errorHorario = '';
		loadingDetalle = true;
		seleccionado = null;
		horario = [];

		if (puestos.length === 0) {
			try {
				puestos = await listarPuestos();
			} catch {
				// no bloquear si falla puestos
			}
		}

		try {
			const detalle = await obtenerEmpleado(id);
			seleccionado = detalle;
			fNombre = detalle.Nombre;
			fApellido = detalle.Apellido;
			fFechaIngreso = detalle.FechaIngreso?.slice(0, 10) ?? '';
			fFechaNacimiento = detalle.FechaNacimiento?.slice(0, 10) ?? '';
			fPuestoId = detalle.idPuesto;
			fActivo = detalle.Activo;
		} catch (e) {
			errorForm = e instanceof ApiError ? `Error ${e.status}` : 'No se pudo cargar el empleado';
		} finally {
			loadingDetalle = false;
		}

		// Load horario independently so employee info still shows if it fails
		loadingHorario = true;
		try {
			horario = await obtenerHorarioEmpleado(id);
		} catch {
			errorHorario = 'No se pudo cargar el horario';
		} finally {
			loadingHorario = false;
		}
	}

	function cerrarPanel() {
		seleccionado = null;
		errorForm = '';
		mensajeOk = '';
		horario = [];
		errorHorario = '';
	}

	// ── Guardar edición ───────────────────────────────────────────────────────
	async function guardar() {
		if (!seleccionado) return;
		errorForm = '';
		mensajeOk = '';
		loadingGuardar = true;

		try {
			await editarEmpleado(seleccionado.id, {
				nombre: fNombre.trim(),
				apellido: fApellido.trim(),
				fecha_ingreso: fFechaIngreso,
				fecha_nacimiento: fFechaNacimiento || null,
				puesto_id: fPuestoId,
				activo: fActivo
			});
			mensajeOk = 'Cambios guardados correctamente.';
			empleados = filtro.trim() ? await buscarEmpleados(filtro.trim()) : await listarEmpleados();
		} catch (e) {
			errorForm = e instanceof ApiError ? `Error ${e.status}` : 'No se pudieron guardar los cambios';
		} finally {
			loadingGuardar = false;
		}
	}

	// ── Impersonar ────────────────────────────────────────────────────────────
	async function handleImpersonar() {
		if (!seleccionado) return;
		loadingImpersonar = true;
		errorForm = '';

		try {
			const nuevaAuth = await impersonar(seleccionado.id);
			authStore.updateSession(nuevaAuth);
			goto('/empleado');
		} catch (e) {
			errorForm = e instanceof ApiError ? `Error ${e.status}` : 'No se pudo impersonar';
			loadingImpersonar = false;
		}
	}

	// ── Cerrar sesión ─────────────────────────────────────────────────────────
	async function handleLogout() {
		try {
			await logoutApi();
		} finally {
			authStore.logout();
			goto('/');
		}
	}
</script>

<svelte:head>
	<title>Panel de administración</title>
</svelte:head>

<div class="shell">
	<Header {username} onLogout={handleLogout} />

	<!-- Main content -->
	<div class="content">
		<!-- ── Lista de empleados ── -->
		<aside class="sidebar">
			<div class="sidebar-search">
				<div class="search-wrap">
					<svg
						class="search-icon"
						xmlns="http://www.w3.org/2000/svg"
						viewBox="0 0 24 24"
						fill="none"
						stroke="currentColor"
						stroke-width="2"
						stroke-linecap="round"
						stroke-linejoin="round"
						aria-hidden="true"
					>
						<circle cx="11" cy="11" r="8" />
						<line x1="21" y1="21" x2="16.65" y2="16.65" />
					</svg>
					<input
						type="search"
						bind:value={filtro}
						oninput={onFiltroInput}
						placeholder="Buscar empleado…"
						class="search-input"
					/>
				</div>
			</div>

			<div class="emp-list">
				{#if loadingLista}
					<p class="list-state">Cargando…</p>
				{:else if errorLista}
					<p class="list-state list-state--error">{errorLista}</p>
				{:else if empleados.length === 0}
					<p class="list-state">
						{filtro ? 'Sin resultados.' : 'No hay empleados activos.'}
					</p>
				{:else}
					<ul>
						{#each empleados as emp}
							<li>
								<button
									onclick={() => seleccionar(emp.id)}
									class="emp-item {seleccionado?.id === emp.id ? 'emp-item--active' : ''}"
								>
									<span class="emp-avatar">
										{emp.Nombre[0]}{emp.Apellido[0]}
									</span>
									<span class="emp-info">
										<span class="emp-name">{emp.Nombre} {emp.Apellido}</span>
										<span class="emp-puesto">{emp.Puesto}</span>
									</span>
								</button>
							</li>
						{/each}
					</ul>
				{/if}
			</div>
		</aside>

		<!-- ── Panel de edición ── -->
		<main class="detail">
			{#if loadingDetalle}
				<div class="detail-placeholder">
					<div class="spinner" aria-label="Cargando"></div>
					<p>Cargando empleado…</p>
				</div>
			{:else if seleccionado}
				<div class="detail-inner">
					<div class="detail-header">
						<div>
							<h1 class="detail-name">{seleccionado.Nombre} {seleccionado.Apellido}</h1>
							<p class="detail-meta">Cédula: {seleccionado.Cedula} · ID: {seleccionado.id}</p>
						</div>
						<button class="btn-ghost" onclick={cerrarPanel} aria-label="Cerrar panel">
							<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
								stroke="currentColor" stroke-width="2" stroke-linecap="round"
								stroke-linejoin="round" aria-hidden="true">
								<line x1="18" y1="6" x2="6" y2="18" />
								<line x1="6" y1="6" x2="18" y2="18" />
							</svg>
						</button>
					</div>

					<!-- Info del empleado -->
					<div class="info-card">
						<div class="info-grid">
							<div class="info-field">
								<span class="info-label">Puesto</span>
								<span class="info-value">{seleccionado.NombrePuesto}</span>
							</div>
							<div class="info-field">
								<span class="info-label">Fecha de ingreso</span>
								<span class="info-value">{seleccionado.FechaIngreso?.slice(0, 10) ?? '—'}</span>
							</div>
							<div class="info-field">
								<span class="info-label">Fecha de nacimiento</span>
								<span class="info-value">{seleccionado.FechaNacimiento?.slice(0, 10) ?? '—'}</span>
							</div>
							<div class="info-field">
								<span class="info-label">Estado</span>
								<span class="badge {seleccionado.Activo ? 'badge--active' : 'badge--inactive'}">
									{seleccionado.Activo ? 'Activo' : 'Inactivo'}
								</span>
							</div>
						</div>
					</div>

					<!-- Horario semanal -->
					<div class="section-title">
						Horario semanal
						{#if horario.length > 0}
							<span class="section-range">
								{horario[0].SemanaInicio} – {horario[0].SemanaFin}
							</span>
						{/if}
					</div>

					{#if loadingHorario}
						<p class="horario-state">Cargando horario…</p>
					{:else if errorHorario}
						<p class="horario-state horario-state--error">{errorHorario}</p>
					{:else if horario.length === 0}
						<p class="horario-state">Sin horario asignado.</p>
					{:else}
						<div class="horario-table-wrap">
							<table class="horario-table">
								<thead>
									<tr>
										<th>Día</th>
										<th>Fecha</th>
										<th>Jornada</th>
										<th>Horario</th>
										<th>Descanso</th>
									</tr>
								</thead>
								<tbody>
									{#each horario as dia}
										<tr class={dia.EsDiaDescanso ? 'row-descanso' : ''}>
											<td class="td-dia">{dia.NombreDia}</td>
											<td class="td-fecha">{dia.Fecha}</td>
											<td>{dia.EsDiaDescanso ? '—' : dia.NombreJornada}</td>
											<td class="td-hora">
												{#if dia.EsDiaDescanso}
													—
												{:else}
													{dia.HoraInicio} – {dia.HoraFin}
												{/if}
											</td>
											<td class="td-descanso">
												{#if dia.EsDiaDescanso}
													<span class="badge badge--rest">Sí</span>
												{/if}
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					{/if}

					{#if errorForm}
						<p class="alert alert--error" style="margin-top: 0.5rem">{errorForm}</p>
					{/if}

					<!-- Acción principal -->
					<div class="panel-actions">
						<button onclick={handleImpersonar} disabled={loadingImpersonar} class="btn-primary">
							{loadingImpersonar ? 'Cargando…' : 'Impersonar'}
						</button>
					</div>
				</div>
			{:else}
				<div class="detail-placeholder">
					<svg
						xmlns="http://www.w3.org/2000/svg"
						viewBox="0 0 24 24"
						fill="none"
						stroke="currentColor"
						stroke-width="1.5"
						stroke-linecap="round"
						stroke-linejoin="round"
						aria-hidden="true"
					>
						<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
						<circle cx="9" cy="7" r="4" />
						<path d="M23 21v-2a4 4 0 0 0-3-3.87" />
						<path d="M16 3.13a4 4 0 0 1 0 7.75" />
					</svg>
					<p>Selecciona un empleado para editar</p>
				</div>
			{/if}
		</main>
	</div>
</div>

<style>
	/* ── Reset global element overrides (layout.css h1/h2/p are unlayered so
	   they beat Tailwind-in-@layer; scoped selectors win by specificity) ── */
	h1, p {
		font-size: inherit;
		font-weight: inherit;
		text-align: inherit;
		line-height: inherit;
	}

	/* ── Shell ── */
	.shell {
		display: flex;
		flex-direction: column;
		height: 100vh;
		background: #f9fafb;
		font-family: inherit;
	}

	/* ── Layout ── */
	.content {
		display: flex;
		flex: 1;
		overflow: hidden;
	}

	/* ── Sidebar ── */
	.sidebar {
		display: flex;
		flex-direction: column;
		width: 17rem;
		flex-shrink: 0;
		border-right: 1px solid #e5e7eb;
		background: #fff;
	}

	.sidebar-search {
		padding: 0.875rem;
		border-bottom: 1px solid #f3f4f6;
	}

	.search-wrap {
		position: relative;
	}

	.search-icon {
		position: absolute;
		left: 0.625rem;
		top: 50%;
		transform: translateY(-50%);
		width: 0.875rem;
		height: 0.875rem;
		stroke: #9ca3af;
		pointer-events: none;
	}

	.search-input {
		width: 100%;
		padding: 0.5rem 0.75rem 0.5rem 2rem;
		font-size: 0.8125rem;
		border: 1px solid #d1d5db;
		border-radius: 0.5rem;
		background: #f9fafb;
		color: #111827;
		outline: none;
		box-sizing: border-box;
		transition: border-color 0.15s, box-shadow 0.15s;
	}

	.search-input:focus {
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.12);
		background: #fff;
	}

	.emp-list {
		flex: 1;
		overflow-y: auto;
	}

	.emp-list ul {
		list-style: none;
		margin: 0;
		padding: 0.375rem;
	}

	.list-state {
		padding: 1rem;
		font-size: 0.8125rem;
		color: #9ca3af;
	}

	.list-state--error {
		color: #ef4444;
	}

	.emp-item {
		display: flex;
		align-items: center;
		gap: 0.625rem;
		width: 100%;
		padding: 0.5rem 0.625rem;
		border-radius: 0.5rem;
		border: none;
		background: transparent;
		cursor: pointer;
		text-align: left;
		transition: background 0.1s;
		margin-bottom: 0.125rem;
	}

	.emp-item:hover {
		background: #f3f4f6;
	}

	.emp-item--active {
		background: #eff6ff;
	}

	.emp-item--active .emp-name {
		color: #1d4ed8;
	}

	.emp-avatar {
		width: 2rem;
		height: 2rem;
		border-radius: 50%;
		background: #dbeafe;
		color: #1d4ed8;
		font-size: 0.6875rem;
		font-weight: 600;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		text-transform: uppercase;
		letter-spacing: 0.02em;
	}

	.emp-item--active .emp-avatar {
		background: #bfdbfe;
	}

	.emp-info {
		display: flex;
		flex-direction: column;
		min-width: 0;
	}

	.emp-name {
		font-size: 0.8125rem;
		font-weight: 500;
		color: #111827;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.emp-puesto {
		font-size: 0.725rem;
		color: #9ca3af;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	/* ── Detail panel ── */
	.detail {
		flex: 1;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
	}

	.detail-placeholder {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		color: #9ca3af;
		font-size: 0.875rem;
	}

	.detail-placeholder svg {
		width: 2.5rem;
		height: 2.5rem;
		opacity: 0.4;
	}

	.detail-inner {
		padding: 1.75rem 2rem;
		max-width: 36rem;
		width: 100%;
	}

	.detail-header {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		margin-bottom: 1.25rem;
	}

	.detail-name {
		font-size: 1.125rem;
		font-weight: 600;
		color: #111827;
		margin: 0 0 0.25rem;
	}

	.detail-meta {
		font-size: 0.75rem;
		color: #9ca3af;
		margin: 0;
	}

	/* ── Info card ── */
	.info-card {
		background: #fff;
		border: 1px solid #e5e7eb;
		border-radius: 0.75rem;
		padding: 1.25rem 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
		margin-bottom: 1.25rem;
	}

	.info-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.875rem 1.5rem;
	}

	.info-field {
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
	}

	.info-label {
		font-size: 0.7rem;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #9ca3af;
	}

	.info-value {
		font-size: 0.875rem;
		color: #111827;
		font-weight: 500;
	}

	/* ── Badges ── */
	.badge {
		display: inline-block;
		padding: 0.15rem 0.5rem;
		border-radius: 999px;
		font-size: 0.7rem;
		font-weight: 600;
		letter-spacing: 0.02em;
	}

	.badge--active {
		background: #dcfce7;
		color: #16a34a;
	}

	.badge--inactive {
		background: #fee2e2;
		color: #dc2626;
	}

	.badge--rest {
		background: #fef9c3;
		color: #854d0e;
	}

	/* ── Section heading ── */
	.section-title {
		font-size: 0.8125rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.625rem;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.section-range {
		font-weight: 400;
		color: #9ca3af;
	}

	/* ── Horario table ── */
	.horario-table-wrap {
		overflow-x: auto;
		border: 1px solid #e5e7eb;
		border-radius: 0.75rem;
		background: #fff;
		margin-bottom: 1.25rem;
	}

	.horario-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.8125rem;
	}

	.horario-table th {
		text-align: left;
		padding: 0.5rem 0.875rem;
		font-size: 0.7rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #6b7280;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
	}

	.horario-table td {
		padding: 0.5rem 0.875rem;
		color: #374151;
		border-bottom: 1px solid #f3f4f6;
	}

	.horario-table tr:last-child td {
		border-bottom: none;
	}

	.row-descanso {
		background: #fefce8;
	}

	.td-dia {
		font-weight: 600;
		color: #111827;
	}

	.td-fecha {
		color: #6b7280;
	}

	.td-hora {
		font-variant-numeric: tabular-nums;
	}

	.td-descanso {
		text-align: center;
	}

	.horario-state {
		font-size: 0.8125rem;
		color: #9ca3af;
		padding: 0.75rem 0;
		margin-bottom: 1rem;
	}

	.horario-state--error {
		color: #ef4444;
	}

	/* ── Panel actions ── */
	.panel-actions {
		display: flex;
		gap: 0.625rem;
		padding-top: 0.25rem;
	}

	/* ── Alerts ── */
	.alert {
		padding: 0.5rem 0.75rem;
		border-radius: 0.5rem;
		font-size: 0.8125rem;
		margin: 0;
	}

	.alert--error {
		background: #fef2f2;
		color: #dc2626;
	}

	/* ── Buttons ── */
	.btn-primary {
		flex: 1;
		padding: 0.5rem 1rem;
		font-size: 0.875rem;
		font-weight: 600;
		color: #fff;
		background: #2563eb;
		border: none;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: background 0.15s, opacity 0.15s;
		font-family: inherit;
	}

	.btn-primary:hover:not(:disabled) {
		background: #1d4ed8;
	}

	.btn-primary:disabled {
		opacity: 0.6;
		cursor: not-allowed;
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

	/* ── Spinner ── */
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
</style>
