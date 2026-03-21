.PHONY: backend-install backend-bootstrap backend-run backend-test

backend-install:
	cd backend && python -m venv .venv && . .venv/bin/activate && pip install -e .[dev]

backend-bootstrap:
	cd backend && . .venv/bin/activate && python -m app.bootstrap

backend-run:
	cd backend && . .venv/bin/activate && uvicorn app.main:app --reload

backend-test:
	cd backend && . .venv/bin/activate && pytest -q
