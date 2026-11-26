local RT = AutoCallboardRuntime

RT.api:Problems("ACB", {
  ["BOOT.DEBUG_MODULE_MISSING"] = { class = "refus" },
  ["DIFFICULTY.SERVICE_MISSING"] = { class = "echec" },
  ["DIFFICULTY.SET_REFUSED"] = { class = "echec" },
  ["DIFFICULTY.SELECTION_REFUSED"] = { class = "echec", key = "entryId" },
  ["BOARD.REMOTE_REFUSED"] = { class = "refus", key = "reason" },
  ["BOARD.REMOTE_FAR"] = { class = "refus", key = "reason" },
  ["ABANDON.API_MISSING"] = { class = "echec", key = "count" },
  ["ABANDON.NO_SELECTION"] = { class = "refus" },
  ["ABANDON.GRAFT_LOST"] = { class = "echec", key = "count" },
  ["ABANDON.CANCEL_MISSING"] = { class = "echec" },
})

EbonAPI.Locale.register("AutoCallboard", {
  enUS = {
    PROBLEM_BOOT_DEBUG_MODULE_MISSING = "the debug command did nothing because the debug module is not loaded. Nothing was changed; enable the debug module, then enter the command again",
    PROBLEM_DIFFICULTY_SERVICE_MISSING = "the difficulty {tier} could not be applied because the difficulty service of Project Ebonhold is not available. The difficulty is unchanged; make sure Project Ebonhold is enabled, then try again",
    PROBLEM_DIFFICULTY_SET_REFUSED = "Project Ebonhold refused to change the difficulty to {tier}. The difficulty is unchanged; check that you are resting or out of combat where the change is allowed, then try again",
    PROBLEM_DIFFICULTY_SELECTION_REFUSED = "the difficulty {tier} was not saved because the selected list was not found. Nothing was changed; refresh the lists window and choose the list again",
    PROBLEM_BOARD_REMOTE_REFUSED = "the board refused the {op} ({reason}; contract {questId}) while you were away from it, with the Toolbelt and no window. Nothing was changed; try again, or go to the board and open it",
    PROBLEM_BOARD_REMOTE_FAR = "the board refused the {op} ({reason}; contract {questId}) while you were away from it, with the Toolbelt and no window, because the server requires you to be near the board even with the Toolbelt. Nothing was changed; walk up to the board, then try again",
    PROBLEM_ABANDON_API_MISSING = "the group abandon is unavailable because the abandon service of EbonAPI is not loaded. Nothing was abandoned; enable EbonAPI, then try again ({count} quests)",
    PROBLEM_ABANDON_NO_SELECTION = "the abandon did nothing because no quest is selected on the board. Nothing was abandoned; select a quest, then try again",
    PROBLEM_ABANDON_GRAFT_LOST = "the Abandon button lost its action after the board redrew ({count} quests). Nothing was abandoned; close and reopen the board",
    PROBLEM_ABANDON_CANCEL_MISSING = "the group abandon could not be stopped at your death because the abandon service of EbonAPI is not loaded. Nothing was changed by that; the running group abandon may continue",
  },
  frFR = {
    PROBLEM_BOOT_DEBUG_MODULE_MISSING = "la commande de débogage n'a rien fait car le module de débogage n'est pas chargé. Rien n'a été modifié ; activez le module de débogage, puis saisissez de nouveau la commande",
    PROBLEM_DIFFICULTY_SERVICE_MISSING = "la difficulté {tier} n'a pas pu être appliquée car le service de difficulté de Project Ebonhold n'est pas disponible. La difficulté n'a pas changé ; vérifiez que Project Ebonhold est activé, puis réessayez",
    PROBLEM_DIFFICULTY_SET_REFUSED = "Project Ebonhold a refusé de passer la difficulté à {tier}. La difficulté n'a pas changé ; vérifiez que vous êtes au repos ou hors combat là où le changement est permis, puis réessayez",
    PROBLEM_DIFFICULTY_SELECTION_REFUSED = "la difficulté {tier} n'a pas été enregistrée car la liste choisie est introuvable. Rien n'a été modifié ; actualisez la fenêtre des listes et choisissez de nouveau la liste",
    PROBLEM_BOARD_REMOTE_REFUSED = "le tableau a refusé l'opération {op} ({reason} ; contrat {questId}) alors que vous étiez loin de lui, avec la ceinture et sans fenêtre. Rien n'a été modifié ; réessayez, ou rendez-vous au tableau et ouvrez-le",
    PROBLEM_BOARD_REMOTE_FAR = "le tableau a refusé l'opération {op} ({reason} ; contrat {questId}) à distance, avec la ceinture et sans fenêtre, car le serveur exige d'être près du tableau même avec la ceinture. Rien n'a été modifié ; approchez-vous du tableau, puis réessayez",
    PROBLEM_ABANDON_API_MISSING = "l'abandon groupé est indisponible car le service d'abandon d'EbonAPI n'est pas chargé. Rien n'a été abandonné ; activez EbonAPI, puis réessayez ({count} quêtes)",
    PROBLEM_ABANDON_NO_SELECTION = "l'abandon n'a rien fait car aucune quête n'est sélectionnée sur le tableau. Rien n'a été abandonné ; sélectionnez une quête, puis réessayez",
    PROBLEM_ABANDON_GRAFT_LOST = "le bouton Abandonner a perdu son action après le redessin du tableau ({count} quêtes). Rien n'a été abandonné ; fermez puis rouvrez le tableau",
    PROBLEM_ABANDON_CANCEL_MISSING = "l'abandon groupé n'a pas pu être arrêté à votre mort car le service d'abandon d'EbonAPI n'est pas chargé. Rien n'a été modifié par cela ; l'abandon groupé en cours peut se poursuivre",
  },
  deDE = {
    PROBLEM_BOOT_DEBUG_MODULE_MISSING = "der Debug-Befehl hat nichts bewirkt, weil das Debug-Modul nicht geladen ist. Es wurde nichts geändert; aktivieren Sie das Debug-Modul und geben Sie den Befehl erneut ein",
    PROBLEM_DIFFICULTY_SERVICE_MISSING = "die Schwierigkeit {tier} konnte nicht angewendet werden, weil der Schwierigkeitsdienst von Project Ebonhold nicht verfügbar ist. Die Schwierigkeit ist unverändert; stellen Sie sicher, dass Project Ebonhold aktiviert ist, und versuchen Sie es erneut",
    PROBLEM_DIFFICULTY_SET_REFUSED = "Project Ebonhold hat die Änderung der Schwierigkeit auf {tier} abgelehnt. Die Schwierigkeit ist unverändert; prüfen Sie, ob Sie sich ausruhen oder außerhalb des Kampfes sind, wo die Änderung erlaubt ist, und versuchen Sie es erneut",
    PROBLEM_DIFFICULTY_SELECTION_REFUSED = "die Schwierigkeit {tier} wurde nicht gespeichert, weil die gewählte Liste nicht gefunden wurde. Es wurde nichts geändert; aktualisieren Sie das Listenfenster und wählen Sie die Liste erneut",
    PROBLEM_BOARD_REMOTE_REFUSED = "das Board hat die Aktion {op} abgelehnt ({reason}; Auftrag {questId}), während Sie fern davon waren, mit dem Werkzeuggürtel und ohne Fenster. Nichts wurde geändert; versuchen Sie es erneut oder gehen Sie zum Board und öffnen Sie es",
    PROBLEM_BOARD_REMOTE_FAR = "das Board hat die Aktion {op} abgelehnt ({reason}; Auftrag {questId}) aus der Ferne, mit dem Werkzeuggürtel und ohne Fenster, weil der Server verlangt, dass Sie auch mit dem Werkzeuggürtel nahe am Board sind. Nichts wurde geändert; gehen Sie zum Board und versuchen Sie es erneut",
  },
  esES = {
    PROBLEM_BOOT_DEBUG_MODULE_MISSING = "el comando de depuración no hizo nada porque el módulo de depuración no está cargado. No se cambió nada; active el módulo de depuración y vuelva a introducir el comando",
    PROBLEM_DIFFICULTY_SERVICE_MISSING = "no se pudo aplicar la dificultad {tier} porque el servicio de dificultad de Project Ebonhold no está disponible. La dificultad no ha cambiado; compruebe que Project Ebonhold está activado y vuelva a intentarlo",
    PROBLEM_DIFFICULTY_SET_REFUSED = "Project Ebonhold rechazó cambiar la dificultad a {tier}. La dificultad no ha cambiado; compruebe que está descansando o fuera de combate donde se permite el cambio, y vuelva a intentarlo",
    PROBLEM_DIFFICULTY_SELECTION_REFUSED = "la dificultad {tier} no se guardó porque no se encontró la lista elegida. No se cambió nada; actualice la ventana de listas y elija de nuevo la lista",
    PROBLEM_BOARD_REMOTE_REFUSED = "el tablón rechazó la operación {op} ({reason}; contrato {questId}) mientras estabas lejos de él, con el cinturón y sin ventana. No se cambió nada; inténtalo de nuevo o ve al tablón y ábrelo",
    PROBLEM_BOARD_REMOTE_FAR = "el tablón rechazó la operación {op} ({reason}; contrato {questId}) a distancia, con el cinturón y sin ventana, porque el servidor exige estar cerca del tablón incluso con el cinturón. No se cambió nada; acércate al tablón e inténtalo de nuevo",
  },
})
