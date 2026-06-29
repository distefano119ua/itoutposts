##  ТАСКА 1 — Порівняльна таблиця провайдерів

- **Summary:** [HW] Cloud Providers: порівняльна таблиця AWS vs GCP vs Azure vs Hetzner
- **Description:** Заповнена порівняльна [таблиця](./cloud%20providers/Порівняльна%20таблиця%20Cloud%20Providers.pdf) по чотирьох cloud провайдерах.

![image1](./screenshots/cloud_providers.png)

## ТАСКА 2 — IAM User з обмеженим dev-доступом

- **Summary:** [HW] AWS IAM: User, Group, Policy — read-only доступ до dev ресурсів
- **Description:** Створити IAM-інфраструктуру для dev-розробника, який може тільки переглядати ресурси в dev-середовищі.

### Підзадачі:

#### Sub-task 1: Розмітити тестові ресурси тегами

- тег `Environment=dev` на EC2 інстанс та S3 бакет
![image2](./screenshots/ec-dev.png) ![image3](./screenshots/s3-dev.png)
- тег `Environment=prod` на іншмй EC2 (для перевірки Deny)
![image4](./screenshots/ec-prod.png)

