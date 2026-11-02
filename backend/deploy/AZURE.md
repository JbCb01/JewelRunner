# Wdrożenie JewelRunner na Azure

Wariant: App Service **F1** (darmowy) i PostgreSQL **B1ms** w ofercie studenckiej. API i portal działają pod jednym adresem. Wysyłkę e-maili włącza krok 6.

## Gdzie wpisywać polecenia

Wszystko robisz w przeglądarce na Windowsie, w portalu Azure. Na komputerze nie trzeba nic instalować.

Polecenia z tej instrukcji wpisujesz w **Azure Cloud Shell**: kliknij ikonę `>_` na górnym pasku portal.azure.com i wybierz **Bash**. To terminal działający w chmurze, więc polecenia są takie same niezależnie od Windowsa. Przy pierwszym uruchomieniu wybierz opcję bez konta magazynu („No storage account required”) i subskrypcję Azure for Students.

## 1. Baza danych: utwórz w portalu Azure

CLI nie pokazuje, czy obowiązuje darmowa oferta, dlatego ten krok wykonuje się w portalu.

1. portal.azure.com → **Azure Database for PostgreSQL** → Utwórz → **Serwer elastyczny**.
2. Na karcie **Podstawowe** ustaw:
   - grupa zasobów: `rg-jewelerunner-backend`
   - nazwa serwera: `jewelrunner-db`
   - region: Poland Central
   - typ obciążenia: **Development**
   - przy **Obliczenia i magazyn** kliknij **Konfiguruj serwer**: warstwa **Burstable (Z możliwością serii)**, rozmiar **B1ms**, magazyn **32 GiB**, typ magazynu **Premium SSD**, a nie wersja 2
   - uwierzytelnianie: PostgreSQL. Login administratora musi być inny niż `administrator`, `admin` czy `root`, np. `jradmin`. Hasło wymyśl mocne i zapisz: wpiszesz je w kroku 3
3. Na karcie **Sieć**: dostęp publiczny, zaznacz dostęp z usług platformy Azure.
4. Na ekranie **Przeglądanie i tworzenie** sprawdź szacowany koszt w ramce po prawej.
   - **0 USD:** kliknij Utwórz.
   - **Inna kwota:** nie twórz bazy. Wróć z tą kwotą do decyzji zespołu.

Jeśli region jest odrzucony, wybierz dozwolony region w Europie i użyj tego samego przy kroku 3 (`LOCATION=...`).

## 2. Paczka

Plik `jewelrunner.zip` leży na Pulpicie. Po zmianach w kodzie zbuduj go ponownie w PowerShell (wymaga Pythona i Node.js na Windowsie):

    cd $HOME\Desktop\backend
    python deploy\build_package.py

## 3. Utwórz serwer aplikacji

W Cloud Shell kliknij **Zarządzaj plikami → Przekaż** i wgraj `backend\deploy\provision.sh` oraz `jewelrunner.zip` z Pulpitu. Potem w Cloud Shell:

    az webapp list-runtimes --os-type linux
    bash provision.sh

Na liście wersji sprawdź, czy jest `PYTHON:3.13`. Jeśli grupa zasobów lub serwer bazy mają inne nazwy niż w instrukcji, podaj je przed poleceniem, np. `RESOURCE_GROUP=nazwa-grupy DB_SERVER=nazwa-serwera bash provision.sh`. Tej samej nazwy grupy użyj w poleceniu `az webapp deploy`. Jeśli nazwa `jewelrunner-app` jest zajęta: `APP=inna-nazwa bash provision.sh`. Skrypt zapyta o hasło do bazy i przerwie działanie, jeśli baza ma inny wariant niż B1ms. Wpisywanego hasła nie widać na ekranie.

## 4. Wdróż

W Cloud Shell:

    az webapp deploy --resource-group rg-jewelerunner-backend --name jewelrunner-app --src-path jewelrunner.zip --type zip

Pierwszy start F1 może potrwać kilka minut. Migracje i dane startowe wykonają się automatycznie.

## 5. Sprawdź

- `https://<nazwa>.azurewebsites.net/api/health` zwraca `{"status":"ok","database":"ok"}`.
- Pod adresem głównym otwiera się portal, a rejestracja i lista wyzwań działają.
- W razie problemów, w Cloud Shell: `az webapp log tail --resource-group rg-jewelerunner-backend --name jewelrunner-app`.

## 6. Wysyłka e-maili (ST-04)

W Cloud Shell wgraj `backend\deploy\email.sh` i uruchom:

    RESOURCE_GROUP=rg-jewelrunner-backend bash email.sh

Skrypt tworzy Communication Services z domeną zarządzaną przez Azure i ustawia w aplikacji `EMAIL_BACKEND=acs`. Potem wdróż nową paczkę jak w kroku 4. Domena Azure pozwala wysłać 10 wiadomości na godzinę i jest przeznaczona do testów; wiadomości mogą trafiać do spamu.

## Koszty

Stan sprawdzaj w portalu w **Subscriptions → Azure for Students → Cost analysis**. Jeśli F1 zgłasza `QuotaExceeded` albo przed prezentacją, przełącz plan na B1 (ok. 13 USD miesięcznie):

    az appservice plan update --resource-group rg-jewelerunner-backend --name jewelrunner-plan --sku B1
