# generateICS.py
Automation of a phishing campaign using both an ICS calendar event and an HTML email body

_Most of the code was inspired by [FakeMeeting](https://github.com/ExAndroidDev/fakemeeting)._

## Requirements
The script expects these files in the same directory with the same expected format:
- `mail_data.txt` - Contains email/event details
- `msTeams-template.html` - MS Teams template
- `iCalendar_template.ics` - iCalendar template

## Usage
**Dry Run Mode (Default)**
```bash
python3 generateICS.py --smtp-server smtp.gmail.com \
                 --sender hr@company.com \
                 --recipient "employee1@company.com,employee2@company.com" \
                 --event-url "https://evil.com/abc-defg-hij"
```
**Sending mails**
```bash
python3 generateICS.py --smtp-server mail.company.com \
                 --sender events@company.com \
                 --recipient "team1@company.com,team2@company.com,team3@company.com" \
                 --event-url "https://teams.evil/j/123456789" \
                 --send-campaign
```

## Setup your local SMTP and mail logs
- <https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-as-a-send-only-smtp-server-on-ubuntu-22-04>
- <https://www.electricmonk.nl/log/2015/03/06/keep-an-archive-of-all-mails-going-through-a-postfix-smtp-server/>
