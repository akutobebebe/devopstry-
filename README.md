# DevOps Playground

Навчальний проєкт, у якому невеликий HTTP-сервіс проходить шлях від локального запуску до EC2 в AWS. Тут є Python-застосунок, Docker, перевірки в GitHub Actions, інфраструктура в Terraform і автоматичне оновлення контейнера на сервері.

## Як це працює

```text
Mac: app.py → git push → GitHub
                       ├─ GitHub Actions: тести + перевірка Docker build
                       └─ EC2: systemd timer → перевірка нового коміту
                                              → git pull → Docker build/run
                                              → перевірка /health
```

GitHub Actions **перевіряє** код. Деплой виконує **EC2**: приблизно раз на хвилину вона шукає новий коміт у публічному репозиторії. Тому автоматичне оновлення працює, коли EC2 запущена. Після запуску зупиненої EC2 таймер знову перевірить GitHub.

## Застосунок

Сервіс використовує стандартну бібліотеку Python і слухає порт `8080`.

| Адреса | Відповідь |
| --- | --- |
| `/` | Сторінка з кнопкою перевірки. Вона викликає `/health` і пише HTTP-статус у консоль браузера. |
| `/health` | JSON `{"status": "ok"}` і HTTP 200. |
| `/info` | JSON зі значенням `APP_ENV`; за замовчуванням `local`. |

### Запуск на Mac

Потрібен Python 3.9+:

```bash
python3 app.py
```

В іншому терміналі:

```bash
curl http://localhost:8080/health
python3 -m unittest discover -s tests -v
```

Щоб змінити порт і назву середовища:

```bash
PORT=9000 APP_ENV=dev python3 app.py
```

### Запуск у Docker

```bash
docker build -t devops-playground .
docker run --rm -p 8080:8080 devops-playground
```

Або через Compose:

```bash
docker compose up --build
```

Після запуску відкрий `http://localhost:8080/`. Compose передає `APP_ENV=dev`; Docker-команда вище залишає стандартне `local`.

## AWS-інфраструктура

`terraform/main.tf` описує одну EC2 `t3.micro` з Amazon Linux 2023 у регіоні `eu-north-1`. Terraform знаходить стандартну VPC, підмережу й актуальний AMI, створює security group з відкритим портом `8080` і прикріплює роль для Session Manager. Порт SSH `22` не відкривається.

```bash
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan
```

`terraform plan` показує зміни; `terraform apply` створює або змінює ресурси AWS. Для звичайного **запуску чи зупинки вже створеної EC2** використовуй AWS Console або `aws ec2 start-instances` / `aws ec2 stop-instances`, а не `terraform apply`.

Після зупинки й повторного запуску EC2 отримує нову публічну IP-адресу. Перевір її в AWS Console перед відкриттям сайту. Terraform state зберігається локально в `terraform/terraform.tfstate` і виключений з Git; не видаляй його, поки Terraform керує ресурсами.

Бюджет AWS на $10 надсилає **сповіщення**, але не зупиняє ресурси автоматично. Зупинена EC2 не нараховує плату за обчислення, проте диск EBS продовжує зберігатися й може коштувати грошей.

## Автоматичне оновлення EC2

На сервері репозиторій розміщено в `/home/ssm-user/devops`:

- `scripts/check-for-updates.sh` порівнює локальний коміт з `main` на GitHub.
- `scripts/deploy.sh` підтягує код, збирає Docker-образ, перезапускає контейнер `devops-app` і чекає відповіді `/health`.
- `systemd/devops-playground-update.service` запускає перевірку від `ssm-user`.
- `systemd/devops-playground-update.timer` повторює перевірку приблизно щохвилини та вмикається після старту EC2.

Перевірити таймер і останній деплой у Session Manager:

```bash
systemctl status devops-playground-update.timer --no-pager
sudo journalctl -u devops-playground-update.service -n 40 --no-pager
sudo docker ps
curl http://localhost:8080/health
```

Якщо потрібно вручну оновити контейнер на EC2:

```bash
cd /home/ssm-user/devops
./scripts/deploy.sh
```

Скрипти й systemd-файли зберігаються в Git, але встановлені unit-файли в `/etc/systemd/system/` живуть на самій EC2. Якщо Terraform створить **нову** машину замість поточної, Docker і таймер на ній потрібно буде налаштувати знову.

## Що можна покращити далі

- Замість відкритого HTTP додати домен і HTTPS.
- Збирати образ один раз у CI та зберігати його в реєстрі, а не збирати на EC2.
- Перенести підготовку EC2 і встановлення таймера в автоматичний bootstrap.
- Додати окреме навчальне розгортання в локальному Kubernetes.

Це навчальний сервіс. На відкритому порту `8080` немає автентифікації; не клади в застосунок секрети чи приватні дані.
