import { Window } from "happy-dom"

const window = new Window({ url: 'https://localhost:8080' })
const document = window.document

///@ts-expect-error: something about types
globalThis.window = window

export {
	window,
	document,
}
