# backend/app/api/uploads.py
from fastapi import APIRouter, UploadFile, File, HTTPException
from pathlib import Path
import uuid

router = APIRouter(prefix="/uploads", tags=["Uploads"])

# Le dossier uploads est à la racine du backend
UPLOAD_DIR = Path(__file__).resolve().parent.parent.parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

@router.post("")
async def upload_image(file: UploadFile = File(...)):
    # Vérification de l'extension
    ext = Path(file.filename or "").suffix.lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
        raise HTTPException(status_code=400, detail="Format non supporté")

    # Génération d'un nom unique pour éviter les conflits
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = UPLOAD_DIR / filename

    # Sauvegarde du fichier
    with open(filepath, "wb") as buffer:
        buffer.write(await file.read())

    # On retourne le chemin relatif. 
    # Le front (web ou mobile) ajoutera l'URL de base (http://127.0.0.1:8000)
    return {"image_url": f"/uploads/{filename}"}