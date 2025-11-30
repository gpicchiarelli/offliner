# Contribuire a OffLiner

Grazie per il tuo interesse a contribuire a OffLiner! Questo documento fornisce linee guida per contribuire al progetto.

## Come Contribuire

### Segnalare Bug

Se trovi un bug, per favore apri una issue su GitHub con:
- Descrizione chiara del problema
- Passi per riprodurre il bug
- Comportamento atteso vs comportamento attuale
- Versione di Perl e sistema operativo
- Output di eventuali errori

### Proporre Nuove Funzionalità

Le proposte di nuove funzionalità sono benvenute! Apri una issue descrivendo:
- La funzionalità proposta
- Il caso d'uso
- Eventuali esempi di utilizzo

### Inviare Pull Request

1. **Fork del repository**
   ```bash
   git clone https://github.com/gpicchiarelli/offliner.git
   cd offliner
   ```

2. **Crea un branch per la tua feature**
   ```bash
   git checkout -b feature/nome-feature
   ```

3. **Fai le modifiche**
   - Segui lo stile di codice esistente
   - Aggiungi test se appropriato
   - Aggiorna la documentazione se necessario

4. **Esegui i test**
   ```bash
   perl Makefile.PL
   make test
   ```

5. **Verifica la sintassi**
   ```bash
   perl -c offliner.pl
   ```

6. **Commit e push**
   ```bash
   git add .
   git commit -m "Descrizione chiara delle modifiche"
   git push origin feature/nome-feature
   ```

7. **Apri una Pull Request** su GitHub

## Linee Guida per il Codice

### Stile

- Usa `perltidy` o segui lo stile esistente
- Indentazione: 4 spazi
- Usa `strict` e `warnings`
- Commenta codice complesso
- Usa nomi di variabili descrittivi

### Testing

- Aggiungi test per nuove funzionalità
- Assicurati che tutti i test passino
- Test dovrebbero essere chiari e ben documentati

### Documentazione

- Aggiorna POD per nuove funzionalità
- Aggiorna README.md se necessario
- Aggiorna CHANGELOG.md per cambiamenti notevoli

## Ambiente di Sviluppo

### Requisiti

- Perl 5.10 o superiore
- Moduli Perl elencati in Makefile.PL

### Setup

```bash
# Installa le dipendenze
cpanm --installdeps .

# Oppure con cpan
cpan --installdeps .
```

### Eseguire i Test

```bash
perl Makefile.PL
make test
```

### Verificare la Sintassi

```bash
perl -c offliner.pl
perlcritic offliner.pl  # Se installato
```

## Domande?

Se hai domande, apri una issue o contatta il maintainer.

Grazie per il tuo contributo! 🎉


