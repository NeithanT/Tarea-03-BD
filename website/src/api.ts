export interface LoginPayload {
	username: string;
	password: string;
}

export interface LoginResponse {
	success: boolean;
	message: string;
	token?: string;
}

export async function login(payload: LoginPayload): Promise<LoginResponse> {
	const response = await fetch('http://localhost:3000/auth/login', {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json'
		},
		body: JSON.stringify(payload)
	});

	if (!response.ok) {
		const contentType = response.headers.get('content-type') || '';
		if (contentType.includes('application/json')) {
			const errorBody = await response.json();
			throw new Error(errorBody.message || JSON.stringify(errorBody));
		}

		const errorText = await response.text();
		throw new Error(errorText || 'Login request failed');
	}

	return response.json();
}
