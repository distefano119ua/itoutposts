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

#### Sub-task 2: Створити IAM Policy `DevReadOnlyByTag`

```JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllActionsOnProdTaggedResources",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Environment": "prod"
        }
      }
    },
    {
      "Sid": "DenyS3ObjectActionsOnProdTaggedObjects",
      "Effect": "Deny",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::*/*",
      "Condition": {
        "StringEquals": {
          "s3:ExistingObjectTag/Environment": "prod"
        }
      }
    },
    {
      "Sid": "AllowEC2AndRDSDescribeForDevTaggedResources",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "rds:Describe*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Environment": "dev"
        }
      }
    },
    {
      "Sid": "AllowS3ListDevTaggedBuckets",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Environment": "dev"
        }
      }
    },
    {
      "Sid": "AllowS3GetDevTaggedObjects",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::*/*",
      "Condition": {
        "StringEquals": {
          "s3:ExistingObjectTag/Environment": "dev"
        }
      }
    },
    {
      "Sid": "AllowGlobalReadOnlyIAMAndCloudWatch",
      "Effect": "Allow",
      "Action": [
        "iam:Get*",
        "iam:List*",
        "cloudwatch:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
```