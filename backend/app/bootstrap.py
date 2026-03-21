from app.db import Base, engine
from app import models  # noqa: F401  # ensure models are registered


def main() -> None:
    Base.metadata.create_all(bind=engine)
    print('Initialized database tables.')


if __name__ == '__main__':
    main()
