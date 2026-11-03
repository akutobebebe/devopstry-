# DevOps Playground

Навчальний проєкт, який демонструє шлях невеликого HTTP-сервісу від локального запуску до EC2 в AWS. Репозиторій містить Python-застосунок, Docker-конфігурацію, перевірки в GitHub Actions, інфраструктуру в Terraform і скрипти автоматичного оновлення контейнера на сервері.

## Як це працює

```text
Локальний комп’ютер: app.py → git push → GitHub
                       ├─ GitHub Actions: тести + перевірка Docker build
                       └─ EC2: systemd timer → перевірка нового коміту
                                              → git pull → Docker build/run
                                              → перевірка /health
```

GitHub Actions **перевіряє** код. Деплой виконує **EC2**: приблизно раз на хвилину вона шукає новий коміт у публічному репозиторії. Автоматичне оновлення працює, коли EC2 запущена. Після запуску зупиненої EC2 таймер знову перевіряє GitHub. CI і деплой тут незалежні: успішний деплой не чекає на результат GitHub Actions.

## Застосунок

Сервіс використовує стандартну бібліотеку Python і слухає порт `8080`.

| Адреса | Відповідь |
| --- | --- |
| `/` | Сторінка з кнопкою перевірки. Вона викликає `/health` і пише HTTP-статус у консоль браузера. |
| `/health` | JSON `{"status": "ok"}` і HTTP 200. |
| `/info` | JSON зі значенням `APP_ENV`; за замовчуванням `local`. |

### Локальний запуск

Потрібен Python 3.9+. Команди виконуються з кореня репозиторію:

```bash
python3 app.py
```

В іншому терміналі:

```bash
curl http://localhost:8080/health
python3 -m unittest discover -s tests -v
```

Приклад зміни порту й назви середовища:

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

Після запуску сторінка доступна за адресою `http://localhost:8080/`. Compose передає `APP_ENV=dev`; Docker-команда вище залишає стандартне `local`.

## AWS-інфраструктура

`terraform/main.tf` описує одну EC2 `t3.micro` з Amazon Linux 2023 у регіоні `eu-north-1`. Terraform знаходить стандартну VPC, підмережу й актуальний AMI, створює security group з відкритим портом `8080` і прикріплює роль для Session Manager. Порт SSH `22` не відкривається. Для повторного використання конфігурації потрібен AWS-акаунт із відповідними дозволами та налаштований AWS CLI.

```bash
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan
```

`terraform plan` показує зміни; `terraform apply` створює або змінює ресурси AWS. Уже створену EC2 можна запускати й зупиняти через AWS Console або команди `aws ec2 start-instances` / `aws ec2 stop-instances`.

Після зупинки й повторного запуску EC2 отримує нову публічну IP-адресу. Поточну адресу можна знайти в AWS Console. Terraform state зберігається локально в `terraform/terraform.tfstate` і виключений з Git. Його потрібно зберігати, поки Terraform керує створеними ресурсами.

Перед створенням ресурсів варто налаштувати AWS Budget. Бюджет надсилає **сповіщення**, але не зупиняє ресурси автоматично. Зупинена EC2 не нараховує плату за обчислення, проте диск EBS продовжує зберігатися й може коштувати грошей.

## Автоматичне оновлення EC2

Поточні systemd-файли розраховані на розташування репозиторію `/home/ssm-user/devops` і користувача `ssm-user`. Для іншого шляху або користувача потрібно змінити `WorkingDirectory`, `ExecStart` і `User` у service-файлі.

Компоненти оновлення:

- `scripts/check-for-updates.sh` порівнює локальний коміт з `main` на GitHub.
- `scripts/deploy.sh` підтягує код, збирає Docker-образ, перезапускає контейнер `devops-app` і чекає відповіді `/health`.
- `systemd/devops-playground-update.service` запускає перевірку від `ssm-user`.
- `systemd/devops-playground-update.timer` повторює перевірку приблизно щохвилини та вмикається після старту EC2.

Команди для перевірки таймера й останнього деплою в Session Manager:

```bash
systemctl status devops-playground-update.timer --no-pager
sudo journalctl -u devops-playground-update.service -n 40 --no-pager
sudo docker ps
curl http://localhost:8080/health
```

Ручне оновлення контейнера на EC2:

```bash
cd /home/ssm-user/devops
./scripts/deploy.sh
```

Скрипти й systemd-файли зберігаються в Git, але встановлені unit-файли в `/etc/systemd/system/` живуть на самій EC2. Якщо Terraform створить **нову** машину замість поточної, Docker і таймер на ній потрібно буде налаштувати знову.

