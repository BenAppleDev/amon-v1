from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse, RedirectResponse

ROOT_DIR = Path(__file__).resolve().parents[3]
OPS_DASHBOARD_DIR = ROOT_DIR / 'ops-dashboard'
OPS_ASSETS_DIR = OPS_DASHBOARD_DIR / 'assets'

router = APIRouter(tags=['ops_surface'])


@router.get('/ops')
async def ops_root_redirect() -> RedirectResponse:
    return RedirectResponse(url='/ops/', status_code=307)


@router.get('/ops/')
async def ops_index() -> FileResponse:
    index_path = OPS_DASHBOARD_DIR / 'index.html'
    if not index_path.exists():
        raise HTTPException(status_code=404, detail='Ops dashboard is not available.')
    return FileResponse(index_path)


@router.get('/ops/assets/{asset_path:path}')
async def ops_assets(asset_path: str) -> FileResponse:
    resolved = (OPS_ASSETS_DIR / asset_path).resolve()
    if OPS_ASSETS_DIR.resolve() not in resolved.parents or not resolved.exists():
        raise HTTPException(status_code=404, detail='Asset not found.')
    return FileResponse(resolved)
