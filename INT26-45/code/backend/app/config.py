from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration settings."""
    app_logs_path: str
    alert_email: str
    service_name: str
    mongo_uri: str
    db_name: str
    collection_name: str

    model_config = SettingsConfigDict(
        env_file=".env.example",
        env_file_encoding="utf-8"
    )

settings = Settings()

