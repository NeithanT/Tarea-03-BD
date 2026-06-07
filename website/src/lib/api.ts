import { PUBLIC_API_URL } from '$env/static/public';
import { authStore } from '$lib/auth';
import type { AuthState, Empleado, EmpleadoDetalle, EmpleadoPayload, Puesto } from '$lib/types';

const BASE = PUBLIC_API_URL;

export class ApiError extends Error {
	constructor(
		public status: number,
		message: string
	) {
		super(message);
	}
}

async function request<T>(
	path: string,
	options: RequestInit = {},
	authenticated = true
): Promise<T> {
	const headers: Record<string, string> = {
		'Content-Type': 'application/json',
		...(options.headers as Record<string, string>)
	};

	if (authenticated) {
		const token = authStore.getToken();
		if (token) headers['Authorization'] = `Bearer ${token}`;
	}

	const res = await fetch(`${BASE}${path}`, { ...options, headers });

	if (!res.ok) {
		const text = await res.text().catch(() => res.statusText);
		throw new ApiError(res.status, text);
	}

	if (res.status === 204) return undefined as T;

	return res.json() as Promise<T>;
}

export async function loginApi(username: string, password: string): Promise<AuthState> {
	const data = await request<{ token: string; user: AuthState['user'] }>(
		'/api/auth/login',
		{ method: 'POST', body: JSON.stringify({ username, password }) },
		false
	);
	return { token: data.token, user: data.user };
}

export async function logoutApi(): Promise<void> {
	await request<void>('/api/auth/logout', { method: 'POST' });
}

export async function listarEmpleados(): Promise<Empleado[]> {
	const res = await request<{ data: Empleado[] }>('/api/admin/empleados');
	return res.data;
}

export async function buscarEmpleados(filtro: string): Promise<Empleado[]> {
	const params = new URLSearchParams({ filtro });
	const res = await request<{ data: Empleado[] }>(`/api/admin/empleados/buscar?${params}`);
	return res.data;
}

export async function obtenerEmpleado(id: number): Promise<EmpleadoDetalle> {
	const res = await request<{ data: EmpleadoDetalle[] }>(`/api/admin/empleados/${id}`);
	// El SP retorna un array; tomamos el primer elemento
	const empleado = res.data[0];
	if (!empleado) throw new ApiError(404, `Empleado ${id} no encontrado`);
	return empleado;
}

export async function editarEmpleado(id: number, payload: EmpleadoPayload): Promise<void> {
	await request<void>(`/api/admin/empleados/${id}`, {
		method: 'PUT',
		body: JSON.stringify(payload)
	});
}

export async function listarPuestos(): Promise<Puesto[]> {
	const res = await request<{ data: Puesto[] }>('/api/admin/puestos');
	return res.data;
}

export async function impersonar(empleadoId: number): Promise<AuthState> {
	const data = await request<{ session: AuthState['user']; token?: string }>('/api/admin/impersonar', {
		method: 'POST',
		body: JSON.stringify({ empleado_id: empleadoId })
	});
	const token = authStore.getToken()!;
	return { token, user: data.session };
}


// Retorna 204 sin body; el caller debe limpiar impersonated_employee_id del store
export async function regresarAdmin(): Promise<void> {
	await request<void>('/api/empleado/regresar-admin', { method: 'POST' });
}

export async function planillasSemanales(limit?: number) {
	const params = limit != null ? `?limit=${limit}` : '';
	const res = await request<{ data: unknown[] }>(`/api/empleado/planillas-semanales${params}`);
	return res.data;
}

export async function planillasMensuales(limit?: number) {
	const params = limit != null ? `?limit=${limit}` : '';
	const res = await request<{ data: unknown[] }>(`/api/empleado/planillas-mensuales${params}`);
	return res.data;
}
