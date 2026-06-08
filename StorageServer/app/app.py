import os
from flask import (
    Flask,
    request,
    jsonify,
    render_template,
    abort,
)
from uploader import AzureUploader
app = Flask(__name__)
# Limite máximo de upload (padrão: 500 MB)
MAX_MB = int(os.environ.get("MAX_UPLOAD_MB", 500))
app.config["MAX_CONTENT_LENGTH"] = MAX_MB * 1024 * 1024
uploader = AzureUploader()

# ── Rotas ────────────────────────────────────────────────────
@app.route("/")
def index():
    return render_template("index.html", max_mb=MAX_MB)

@app.route("/api/upload", methods=["POST"])
def upload():
    """
    Recebe múltiplos arquivos com seus caminhos relativos.
    O campo 'relativePaths[]' preserva a estrutura de diretórios.
    """
    files = request.files.getlist("files[]")
    relative_paths = request.form.getlist("relativePaths[]")
    base_prefix = request.form.get("basePrefix", "").strip("/")

    if not files:
        return jsonify({"error": "Nenhum arquivo enviado."}), 400

    results = []
    errors = []

    for idx, file in enumerate(files):
        if file.filename == "":
            continue

        # Usa o caminho relativo para preservar estrutura de pastas
        rel_path = relative_paths[idx] if idx < len(relative_paths) else file.filename

        # Monta o caminho completo dentro do blob container
        if base_prefix:
            blob_path = f"{base_prefix}/{rel_path}"
        else:
            blob_path = rel_path

        try:
            result = uploader.upload_file(file.stream, blob_path)
            results.append(
                {
                    "file": rel_path,
                    "blob_path": result["blob_path"],
                    "status": "ok",
                }
            )
        except Exception as exc:
            errors.append({"file": rel_path, "error": str(exc)})

    return jsonify(
        {
            "uploaded": len(results),
            "failed": len(errors),
            "results": results,
            "errors": errors,
        }
    )

@app.route("/api/blobs", methods=["GET"])
def list_blobs():
    """Lista blobs no container."""
    prefix = request.args.get("prefix", "")
    try:
        blobs = uploader.list_blobs(prefix)
        return jsonify({"blobs": blobs, "total": len(blobs)})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500

@app.route("/api/blobs/delete", methods=["DELETE"])
def delete_blob():
    """Remove um blob."""
    blob_path = request.json.get("blob_path", "") if request.json else ""
    if not blob_path:
        return jsonify({"error": "blob_path obrigatório"}), 400
    try:
        uploader.delete_blob(blob_path)
        return jsonify({"deleted": blob_path})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500

@app.errorhandler(413)
def request_entity_too_large(_):
    return (
        jsonify({"error": f"Arquivo(s) excedem o limite de {MAX_MB} MB."}),
        413,
    )

if __name__ == "__main__":
    port = int(os.environ.get("APP_PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)