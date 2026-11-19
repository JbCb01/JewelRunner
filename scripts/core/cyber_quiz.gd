class_name CyberQuiz

## Pula pytań i mechanika Knowledge Check z cyberbezpieczeństwa.
## Zawiera 15 pytań wielokrotnego wyboru (ABCD) losowanych przy uruchomieniu poziomu.

const QUESTIONS: Array[Dictionary] = [
	{
		"id": 1,
		"topic": "Phishing",
		"question": "Czym charakteryzuje się cyberatak typu Phishing?",
		"options": [
			"A) Próbą wyłudzenia danych (haseł, kart) przez podszywanie się pod zaufaną instytucję",
			"B) Formatowaniem dysku twardego w celu usunięcia złośliwego oprogramowania",
			"C) Przyspieszaniem transferu danych poprzez optymalizację pakietów TCP",
			"D) Automatycznym blokowaniem spamu na serwerze pocztowym"
		],
		"correct": 0,
		"explanation": "Phishing to socjotechniczny atak polegający na podszywaniu się pod zaufany podmiot w celu kradzieży poufnych danych."
	},
	{
		"id": 2,
		"topic": "Uwierzytelnianie 2FA / MFA",
		"question": "Na czym polega bezpieczne uwierzytelnianie dwuskładnikowe (2FA)?",
		"options": [
			"A) Na podaniu tego samego hasła dwukrotnie podczas logowania",
			"B) Na wymaganiu dwóch niezależnych metod weryfikacji tożsamości (np. hasło + kod z aplikacji)",
			"C) Na jednoczesnym logowaniu z dwóch różnych przeglądarek internetowych",
			"D) Na wymuszonej zmianie hasła co 14 dni"
		],
		"correct": 1,
		"explanation": "2FA wymaga dwóch różnych składników (np. coś co znasz - hasło, i coś co posiadasz - token/smartfon)."
	},
	{
		"id": 3,
		"topic": "Ransomware",
		"question": "Jaki jest główny mechanizm działania ataku złośliwego oprogramowania Ransomware?",
		"options": [
			"A) Trwałe usuwanie kont użytkowników w mediach społecznościowych",
			"B) Podglądanie użytkownika przez kamerkę internetową",
			"C) Szyfrowanie plików na dysku i żądanie okupu finansowego za klucz deszyfrujący",
			"D) Zmiana tapety pulpitu i wyłączenie karty dźwiękowej"
		],
		"correct": 2,
		"explanation": "Ransomware szyfruje newralgiczne dane ofiary i blokuje do nich dostęp aż do zapłacenia okupu."
	},
	{
		"id": 4,
		"topic": "Bezpieczeństwo Haseł",
		"question": "Która cecha ma największy wpływ na wysokie bezpieczeństwo hasła dostępowego?",
		"options": [
			"A) Oparcie hasła o imię zwierzęcia i rok urodzenia (np. Burek2020)",
			"B) Duża długość (min. 14-16 znaków), unikalność oraz kombinacja różnych znaków",
			"C) Stosowanie dokładnie takiego samego, trudnego hasła we wszystkich serwisach",
			"D) Wpisywanie hasła wyłącznie przy włączonym klawiszu Caps Lock"
		],
		"correct": 1,
		"explanation": "Długość i unikalność hasła (najlepiej zarządzanego menedżerem haseł) drastycznie utrudniają ataki siłowe."
	},
	{
		"id": 5,
		"topic": "Inżynieria Społeczna (Social Engineering)",
		"question": "Czym jest inżynieria społeczna w kontekście cyberbezpieczeństwa?",
		"options": [
			"A) Projektowaniem ergonomicznego sprzętu komputerowego",
			"B) Programowaniem botów do obsługi portali społecznościowych",
			"C) Manipulowaniem ludźmi w celu nakłonienia ich do ujawnienia poufnych danych lub haseł",
			"D) Automatycznym zarządzaniem uprawnieniami w systemie Linux"
		],
		"correct": 2,
		"explanation": "Inżynieria społeczna wykorzystuje błędy ludzkie, zaufanie lub pośpiech zamiast luk technicznych w oprogramowaniu."
	},
	{
		"id": 6,
		"topic": "Sieci VPN",
		"question": "Jaka jest podstawowa rola technologii VPN (Virtual Private Network)?",
		"options": [
			"A) Szyfrowanie transmisji sieciowej i ochrona prywatności przed podsłuchem w sieci",
			"B) Czyszczenie fizycznej pamięci operacyjnej RAM",
			"C) Fizyczne zwiększanie przepustowości łącza internetowego",
			"D) Automatyczne usuwanie złośliwego kodu z plików Word i Excel"
		],
		"correct": 0,
		"explanation": "VPN tworzy szyfrowany tunel między urządzeniem a serwerem docelowym, maskując ruch i adres IP."
	},
	{
		"id": 7,
		"topic": "Aktualizacje Oprogramowania",
		"question": "Dlaczego regularne instalowanie łatek i aktualizacji systemu jest kluczowe?",
		"options": [
			"A) Ponieważ usuwają one historię przeglądania stron WWW",
			"B) Ponieważ eliminują znane podatności (luki), zanim zostaną wykorzystane przez atakujących",
			"C) Ponieważ zapobiegają przegrzewaniu się karty graficznej",
			"D) Ponieważ zwalniają miejsce w chmurze dyskowej"
		],
		"correct": 1,
		"explanation": "Większość ataków sieciowych wykorzystuje znane publicznie podatności (CVE), na które producenci wydali już łatki."
	},
	{
		"id": 8,
		"topic": "Zasada Kopii Zapasowych 3-2-1",
		"question": "Na czym polega powszechna zasada tworzenia kopii zapasowych 3-2-1?",
		"options": [
			"A) 3 hasła, 2 konta, 1 komputer roboczy",
			"B) 3 próby wpisania PIN-u, 2 minuty blokady, 1 kontakt do administratora",
			"C) 3 kopie danych, na 2 różnych nośnikach, w tym co najmniej 1 poza główną lokalizacją/chmura",
			"D) 3 godziny skanowania, 2 kopie w koszu, 1 restart systemu"
		],
		"correct": 2,
		"explanation": "Zasada 3-2-1 gwarantuje odzyskanie danych nawet w przypadku awarii sprzętu, pożaru lub zaszyfrowania przez ransomware."
	},
	{
		"id": 9,
		"topic": "Zapora Sieciowa (Firewall)",
		"question": "Jaką funkcję pełni zapora sieciowa (Firewall)?",
		"options": [
			"A) Monitoruje i filtruje przychodzący oraz wychodzący ruch sieciowy w oparciu o reguły",
			"B) Odzyskuje skasowane przypadkowo pliki z kosza systemowego",
			"C) Przyspiesza renderowanie grafiki w grach 2D",
			"D) Odpowiada za automatyczne wygaszanie ekranu monitora"
		],
		"correct": 0,
		"explanation": "Firewall analizuje pakiety sieciowe i blokuje niedozwolony ruch na podstawie portów, protokołów i reguł bezpieczeństwa."
	},
	{
		"id": 10,
		"topic": "Atak Man-in-the-Middle (MitM)",
		"question": "Na czym polega atak sieciowy Man-in-the-Middle (człowiek pośrodku)?",
		"options": [
			"A) Na fizycznym odłączeniu kabla sieciowego w serwerowni",
			"B) Na potajemnym przechwytywaniu, podsłuchiwaniu lub modyfikacji danych między nadawcą a odbiorcą",
			"C) Na zainfekowaniu procesora komputera kurzem",
			"D) Na zgadywaniu hasła z użyciem słownika wyrazów obcych"
		],
		"correct": 1,
		"explanation": "Atakujący wtrąca się w kanał komunikacji, mogąc podsłuchać lub zmienić przesyłane informacje w czasie rzeczywistym."
	},
	{
		"id": 11,
		"topic": "Protokół HTTPS",
		"question": "Co oznacza ikona kłódki oraz przedrostek „https://” w pasku adresu przeglądarki?",
		"options": [
			"A) Że strona jest całkowicie wolna od wirusów i bezpieczna w 100%",
			"B) Że ruch między przeglądarką a serwerem jest szyfrowany certyfikatem SSL/TLS",
			"C) Że strona internetowa nie wymaga podawania żadnych haseł",
			"D) Że serwis nie korzysta z żadnych zewnętrznych baz danych"
		],
		"correct": 1,
		"explanation": "HTTPS zapewnia poufność i integralność przesyłanych danych, chroniąc przed podsłuchem w lokalnej sieci."
	},
	{
		"id": 12,
		"topic": "Model Zero Trust",
		"question": "Jaka jest fundamentalna doktryna nowoczesnego modelu bezpieczeństwa „Zero Trust”?",
		"options": [
			"A) „Nigdy nie ufaj, zawsze weryfikuj” – każda próba dostępu podlega ścisłemu uwierzytelnieniu",
			"B) Zezwalanie na dostęp bez hasła każdemu urządzeniu podłączonemu kablem w biurze",
			"C) Rezygnacja z programów antywirusowych na rzecz ręcznej kontroli plików",
			"D) Zaufanie do wszystkich domen internetowych z końcówką .org i .com"
		],
		"correct": 0,
		"explanation": "W Zero Trust żadne urządzenie ani użytkownik (nawet wewnątrz sieci firmowej) nie otrzymuje domyślnego zaufania."
	},
	{
		"id": 13,
		"topic": "Atak Brute Force",
		"question": "Czym charakteryzuje się metoda ataku typu Brute Force (atak siłowy)?",
		"options": [
			"A) Fizycznym uderzeniem w obudowę jednostki centralnej",
			"B) Automatycznym, metodycznym testowaniem wszystkich możliwych kombinacji znaków w celu złamania hasła",
			"C) Wysyłaniem spamu do przypadkowych odbiorców",
			"D) Tworzeniem fałszywych profili na forach dyskusyjnych"
		],
		"correct": 1,
		"explanation": "Brute Force testuje kombinacje po kolei (a, b, c... a1, a2...), dlatego długość hasła drastycznie wydłuża czas łamania."
	},
	{
		"id": 14,
		"topic": "Otwarte Sieci Publiczne Wi-Fi",
		"question": "Jakie główne zagrożenie niesie logowanie do poufnych kont w otwartej, nieszyfrowanej sieci Wi-Fi?",
		"options": [
			"A) Ryzyko podsłuchania nieszyfrowanego ruchu i przejęcia danych sesji przez innego użytkownika sieci",
			"B) Natychmiastowe fizyczne uszkodzenie baterii w laptopie",
			"C) Samoczynne odinstalowanie systemu operacyjnego",
			"D) Skasowanie kontaktów w książce telefonicznej"
		],
		"correct": 0,
		"explanation": "W otwartych sieciach Wi-Fi bez ochrony VPN osoba w tym samym segmencie sieci może podsłuchiwać pakiety i dane logowania."
	},
	{
		"id": 15,
		"topic": "Zasada Najmniejszych Uprawnień (Least Privilege)",
		"question": "Na czym polega zasada najmniejszych uprawnień (Principle of Least Privilege)?",
		"options": [
			"A) Na przyznawaniu każdemu użytkownikowi pełnych uprawnień administratora",
			"B) Na przydzielaniu użytkownikom i procesom wyłącznie minimalnych uprawnień niezbędnych do pracy",
			"C) Na całkowitym zakazie instalowania jakichkolwiek programów w firmie",
			"D) Na tworzeniu kont bez hasła dla pracowników tymczasowych"
		],
		"correct": 1,
		"explanation": "Zmniejsza pole ataku – jeśli konto pracownika zostanie przejęte, atakujący ma ograniczone możliwości wyrządzenia szkód."
	}
]

static func get_random_question(excluded_id: int = -1) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for q in QUESTIONS:
		if q.get("id", -1) != excluded_id:
			candidates.append(q)
	if candidates.is_empty():
		candidates = QUESTIONS
	var rand_idx = randi() % candidates.size()
	return candidates[rand_idx].duplicate(true)

static func get_question_by_id(id: int) -> Dictionary:
	for q in QUESTIONS:
		if q.get("id", -1) == id:
			return q.duplicate(true)
	return QUESTIONS[0].duplicate(true)

static func get_all_questions() -> Array[Dictionary]:
	return QUESTIONS.duplicate(true)
