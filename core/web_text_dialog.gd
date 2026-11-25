extends RefCounted
## Cuadro de texto del navegador, por encima del juego (solo en la web): mostrar un texto largo para copiarlo, o
## pedir que se pegue uno.
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## Va en HTML y no en la interfaz de Godot porque en un celular solo un campo del navegador deja pegar (mantener
## apretado » Pegar), y el portapapeles solo se puede escribir desde un toque sobre un botón de la propia página.

## Una función que recibe title, hint, text, el modo ("show" o "ask") y los botones: build_script() le agrega la
## llamada. No usar el operador de formato de GDScript sobre este texto: el CSS tiene "%".
const SCRIPT: String = """
(function (title, hint, text, mode, labels) {
	var old = document.getElementById('game-text-dialog');
	if (old) old.remove();
	function add(parent, tag, style, content) {
		var node = document.createElement(tag);
		node.style.cssText = style;
		if (content !== undefined) node.textContent = content;
		parent.appendChild(node);
		return node;
	}
	var wrap = add(document.body, 'div', 'position:fixed;inset:0;z-index:1000;display:flex;align-items:center;justify-content:center;padding:16px;box-sizing:border-box;background:rgba(0,0,0,.82);font-family:Pixelify,monospace;color:#f4ecd8');
	wrap.id = 'game-text-dialog';
	var box = add(wrap, 'div', 'width:100%;max-width:420px;box-sizing:border-box;padding:16px;display:flex;flex-direction:column;gap:12px;background:#1a120e;border:3px solid #f4ecd8');
	add(box, 'div', 'font-size:24px;text-align:center', title);
	add(box, 'div', 'font-size:16px;line-height:1.35', hint);
	var area = add(box, 'textarea', 'width:100%;height:132px;box-sizing:border-box;padding:8px;font:16px monospace;word-break:break-all;resize:none;user-select:text;-webkit-user-select:text;-webkit-touch-callout:default;touch-action:auto');
	area.value = text;
	area.readOnly = mode === 'show';
	area.spellcheck = false;
	area.setAttribute('autocapitalize', 'off');
	area.setAttribute('autocomplete', 'off');
	var status = add(box, 'div', 'min-height:20px;font-size:16px;color:#f4c542');
	var row = add(box, 'div', 'display:flex;gap:12px');
	function button(label, onClick) {
		var node = add(row, 'button', 'flex:1;min-height:48px;font:18px Pixelify,monospace;color:#1a120e;background:#f4ecd8;border:0', label);
		node.type = 'button';
		node.addEventListener('click', onClick);
	}
	function selectAll() {
		area.focus();
		area.select();
		area.setSelectionRange(0, area.value.length);
	}
	function copyByHand() {
		selectAll();
		var done = false;
		try { done = document.execCommand('copy'); } catch (error) {}
		status.textContent = done ? labels.copied : labels.copy_failed;
	}
	if (mode === 'show') {
		button(labels.copy, function () {
			if (navigator.clipboard && navigator.clipboard.writeText) {
				navigator.clipboard.writeText(area.value).then(function () { status.textContent = labels.copied; }, copyByHand);
			} else {
				copyByHand();
			}
		});
		button(labels.close, function () { wrap.remove(); });
	} else {
		button(labels.cancel, function () { wrap.remove(); });
		button(labels.accept, function () {
			var value = area.value;
			wrap.remove();
			if (window.__gameTextDialogDone) window.__gameTextDialogDone(value);
		});
	}
}
"""

## El callback de JavaScript se suelta si nadie lo retiene.
var _done: JavaScriptObject


## Muestra `text` para copiarlo. `labels`: copy, copied, copy_failed, close.
func show_text(title: String, hint: String, text: String, labels: Dictionary) -> void:
	_open(title, hint, text, "show", labels)


## Pide pegar un texto y llama a `on_text(texto)` si el jugador acepta. `labels`: accept, cancel.
func ask_text(title: String, hint: String, labels: Dictionary, on_text: Callable) -> void:
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		return
	_done = JavaScriptBridge.create_callback(func(args: Array) -> void: on_text.call(str(args[0])))
	window.__gameTextDialogDone = _done
	_open(title, hint, "", "ask", labels)


## El JavaScript completo: la función de SCRIPT llamada con los textos como literales.
static func build_script(title: String, hint: String, text: String, mode: String, labels: Dictionary) -> String:
	var arguments: PackedStringArray = PackedStringArray()
	for value: Variant in [title, hint, text, mode, labels]:
		arguments.append(JSON.stringify(value))
	return SCRIPT.strip_edges() + "(" + ", ".join(arguments) + "))"


func _open(title: String, hint: String, text: String, mode: String, labels: Dictionary) -> void:
	JavaScriptBridge.eval(build_script(title, hint, text, mode, labels), true)
