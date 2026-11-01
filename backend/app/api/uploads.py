"""Routes pour l'upload de fichiers (images de galerie, etc.)."""
from pathlib import Path
import uuid
from fastapi import APIRouter, File, HTTPException, UploadFile

router = APIRouter(prefix="/uploads", tags=["Uploads"])

# Dossier de destination des images
UPLOAD_DIR = Path(__file__).resolve().parent.parent.parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
MAX_SIZE = 5 * 1024 * 1024  # 5 Mo

@router.post("")
async def upload_file(file: UploadFile = File(...)):
    # 1. Vérifier l'extension
    ext = Path(file.filename or "").suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Format non supporté. Formats acceptés : {', '.join(ALLOWED_EXTENSIONS)}",
        )

    # 2. Lire le contenu et vérifier la taille
    content = await file.read()
    if len(content) > MAX_SIZE:
        raise HTTPException(status_code=400, detail="Fichier trop volumineux (max 5 Mo)")
    if not content:
        raise HTTPException(status_code=400, detail="Fichier vide")

    # 3. Générer un nom unique pour éviter les collisions
    filename = f"{uuid.uuid4().hex}{ext}"
    target = UPLOAD_DIR / filename

    # 4. Écrire sur le disque
    target.write_bytes(content)

    # 5. Retourner le chemin relatif (le front ajoutera l'URL de base)
    return {
        "image_url": f"/uploads/{filename}",
        "filename": filename,
        "size": len(content),
    }