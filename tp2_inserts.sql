-- 1. PERSONNES --
INSERT INTO Personne VALUES (t_personne(1, 'David', 'Fincher'));
INSERT INTO Personne VALUES (t_personne(2, 'Brad', 'Pitt'));
INSERT INTO Personne VALUES (t_personne(3, 'Edward', 'Norton'));
INSERT INTO Personne VALUES (t_personne(4, 'Morgan', 'Freeman'));
INSERT INTO Personne VALUES (t_personne(5, 'Alice', 'Moreau'));
INSERT INTO Personne VALUES (t_personne(6, 'Hugo', 'Bernard'));
INSERT INTO Personne VALUES (t_personne(7, 'Camille', 'Leroy'));
INSERT INTO Personne VALUES (t_personne(8, 'Lina', 'Martin'));

-- 2. CONTENUS --
INSERT INTO Contenu
SELECT t_cinema(                                                    -- Film
    1,                                                              -- ID
    'Fight Club',                                                   -- Titre
    'On ne parle pas du Fight Club.',                               -- Description
    'Thriller',                                                     -- Thème
    mots_cles_list('societe', 'combat'),                            -- Mots-clés
    personnes_refs(REF(r)),                                         -- Réalisateur
    1999,                                                           -- Année
    'Etats-Unis',                                                   -- Pays
    139,                                                            -- Durée en minutes
    personnes_refs(REF(a1), REF(a2)),                               -- Acteurs
    personnes_refs()                                                -- Scénaristes
    )
FROM Personne r, Personne a1, Personne a2
WHERE r.id_personne = 1 AND a1.id_personne = 2 AND a2.id_personne = 3;

INSERT INTO Contenu
SELECT t_cinema(                                                    -- Film
    2,                                                              -- ID
    'Seven',                                                        -- Titre
    'On enquête.',                                                  -- Description
    'Thriller',                                                     -- Thème
    mots_cles_list('enquete', 'police'),                            -- Mots-clés
    personnes_refs(REF(r)),                                         -- Réalisateur
    1995,                                                           -- Année
    'Etats-Unis',                                                   -- Pays
    127,                                                            -- Durée en minutes
    personnes_refs(REF(a1), REF(a2)),                               -- Acteurs
    personnes_refs()                                                -- Scénaristes
    )
FROM Personne r, Personne a1, Personne a2
WHERE r.id_personne = 1 AND a1.id_personne = 2 AND a2.id_personne = 4;

INSERT INTO Contenu
SELECT t_serie(                                                     -- Série
    3,                                                              -- ID
    'Les Chroniques de Brume',                                      -- Titre
    'Un village découvre un passage vers un autre monde.',          -- Description
    'Fantasy / Aventure',                                           -- Thème
    mots_cles_list('magie', 'aventure'),                            -- Mots-clés
    personnes_refs(REF(r)),                                         -- Réalisatrice
    2021,                                                           -- Année
    'France',                                                       -- Pays
    saisons_list(                                                   -- Saisons
        t_saison(
            1,                                                      -- Numéro de saison
            6,                                                      -- Nombre d'épisodes
            'La découverte du passage'                              -- Description
        ),
        t_saison(
            2,                                                      -- Numéro de saison
            8,                                                      -- Nombre d'épisodes
            'Le voyage de l''autre côté'                            -- Description
        )
    )
    )
FROM Personne r
WHERE r.id_personne = 5;

INSERT INTO Contenu
SELECT t_jeunesse(                                                  -- Jeunesse
    4,                                                              -- ID
    'Les Petits Astronautes',                                       -- Titre
    'Des enfants explorent une station spatiale.',                  -- Description
    'Anime / Espace',                                               -- Thème
    mots_cles_list('espace', 'amitie'),                             -- Mots-clés
    personnes_refs(REF(r)),                                         -- Réalisatrice
    2020,                                                           -- Année
    'France',                                                       -- Pays
    80,                                                             -- Durée en minutes
    personnes_refs(REF(r)),                                         -- Scénaristes
    personnes_refs(REF(c))                                          -- Compositeurs
    )
FROM Personne r, Personne c
WHERE r.id_personne = 5 AND c.id_personne = 6;

INSERT INTO Contenu
SELECT t_divertissement(                                            -- Divertissement
    5,                                                              -- ID
    'Une soirée en scène',                                          -- Titre
    'Un spectacle mêlant sketchs et chansons.',                     -- Description
    'Humour',                                                       -- Thème
    mots_cles_list('spectacle', 'musique'),                         -- Mots-clés
    personnes_refs(REF(r)),                                         -- Réalisateur
    2022,                                                           -- Année
    'France',                                                       -- Pays
    95,                                                             -- Durée en minutes
    personnes_refs(REF(r)),                                         -- Metteurs en scène
    personnes_refs(REF(i))                                          -- Interprètes
    )
FROM Personne r, Personne i
WHERE r.id_personne = 6 AND i.id_personne = 7;

INSERT INTO Contenu
SELECT t_cinema(                                                    -- Film
    6,                                                              -- ID
    'La Forêt des lucioles',                                        -- Titre
    'Une garde forestière suit des lumières mystérieuses.',         -- Description
    'Fantasy / Nature',                                             -- Thème
    mots_cles_list('foret', 'magie'),                               -- Mots-clés
    personnes_refs(REF(r)),                                         -- Réalisatrice
    2021,                                                           -- Année
    'France',                                                       -- Pays
    105,                                                            -- Durée en minutes
    personnes_refs(REF(a)),                                         -- Acteurs
    personnes_refs(REF(r))                                          -- Scénaristes
    )
FROM Personne r, Personne a
WHERE r.id_personne = 8 AND a.id_personne = 7;

-- 3. FORMULES D'ABONNEMENT --
INSERT INTO Abonnement (
    id_abonnement, nom_formule, prix_mensuel, nb_locations_max,
    duree_cinema, duree_serie, duree_jeunesse, duree_divertissement
)
VALUES (
    1,                                                              -- ID
    'Basique',                                                      -- Nom de la formule
    9.99,                                                           -- Prix mensuel
    2,                                                              -- Nombre maximal de locations simultanées
    1,                                                              -- Durée maximale : cinéma (jours)
    1,                                                              -- Durée maximale : série (jours)
    2,                                                              -- Durée maximale : jeunesse (jours)
    2                                                               -- Durée maximale : divertissement (jours)
);

INSERT INTO Abonnement (
    id_abonnement, nom_formule, prix_mensuel, nb_locations_max,
    duree_cinema, duree_serie, duree_jeunesse, duree_divertissement
)
VALUES (
    2,                                                              -- ID
    'Prénium',                                                      -- Nom de la formule
    14.99,                                                          -- Prix mensuel
    5,                                                              -- Nombre maximal de locations simultanées
    4,                                                              -- Durée maximale : cinéma (jours)
    4,                                                              -- Durée maximale : série (jours)
    5,                                                              -- Durée maximale : jeunesse (jours)
    5                                                               -- Durée maximale : divertissement (jours)
);

INSERT INTO Abonnement (
    id_abonnement, nom_formule, prix_mensuel, nb_locations_max,
    duree_cinema, duree_serie, duree_jeunesse, duree_divertissement
)
VALUES (
    3,                                                              -- ID
    'VIP',                                                          -- Nom de la formule
    19.99,                                                          -- Prix mensuel
    10,                                                             -- Nombre maximal de locations simultanées
    10,                                                             -- Durée maximale : cinéma (jours)
    10,                                                             -- Durée maximale : série (jours)
    10,                                                             -- Durée maximale : jeunesse (jours)
    10                                                              -- Durée maximale : divertissement (jours)
);


-- 4. CLIENTS --
INSERT INTO CompteClient (
    id_client, prenom, nom, adresse, mail, telephone, hash_mdp,
    achats, locations, abonnement
)
SELECT
    1,                                                              -- ID
    'Jean',                                                         -- Prénom
    'Dupont',                                                       -- Nom
    '1 rue des Tests, Poitiers',                                    -- Adresse
    'jean.dupont@example.test',                                     -- Mail
    '0600000001',                                                   -- Téléphone
    'test_1',                                                       -- Mot de passe
    achat_list(                                                     -- Achats
        t_achat(
            REF(j),                                                 -- Contenu : Les Petits Astronautes
            NULL                                                    -- Contenu entier
        )
    ),
    location_list(                                                  -- Locations
        t_location(
            REF(fc),                                                -- Contenu : Fight Club
            t_dates(DATE '2022-01-10', DATE '2022-01-12'),          -- Dates de début et de fin
            NULL                                                    -- Contenu entier
        ),
        t_location(
            REF(s),                                                 -- Contenu : Les Chroniques de Brume
            t_dates(DATE '2022-03-05', DATE '2022-03-10'),          -- Dates de début et de fin
            1                                                       -- Numéro de saison
        ),
        t_location(
            REF(sv),                                                -- Contenu : Seven
            t_dates(DATE '2022-04-10', DATE '2022-04-12'),          -- Dates hors de la période demandée en B2.2
            NULL                                                    -- Contenu entier
        ),
        t_location(
            REF(f),                                                 -- Contenu : La Forêt des lucioles
            t_dates(TRUNC(SYSDATE) - 1, TRUNC(SYSDATE) + 2),        -- Location en cours
            NULL                                                    -- Contenu entier
        )
    ),
    t_abonnement(                                                   -- Abonnement effectif
        2,                                                          -- Formule Prénium
        t_dates(DATE '2022-01-01', TRUNC(SYSDATE) + 30)             -- Dates de validité
    )
FROM Contenu fc, Contenu s, Contenu sv, Contenu f, Contenu j
WHERE fc.id_contenu = 1 AND s.id_contenu = 3 AND sv.id_contenu = 2
  AND f.id_contenu = 6 AND j.id_contenu = 4;

INSERT INTO CompteClient (
    id_client, prenom, nom, adresse, mail, telephone, hash_mdp,
    achats, locations, abonnement
)
SELECT
    2,                                                              -- ID
    'Marie',                                                        -- Prénom
    'Martin',                                                       -- Nom
    '2 rue des Tests, Poitiers',                                    -- Adresse
    'marie.martin@example.test',                                    -- Mail
    '0600000002',                                                   -- Téléphone
    'test_2',                                                       -- Mot de passe
    achat_list(                                                     -- Achats
        t_achat(
            REF(fc),                                                -- Contenu : Fight Club
            NULL                                                    -- Contenu entier
        )
    ),
    location_list(                                                  -- Locations
        t_location(
            REF(sv),                                                -- Contenu : Seven
            t_dates(TRUNC(SYSDATE) - 2, TRUNC(SYSDATE) + 3),        -- Location en cours
            NULL                                                    -- Contenu entier
        ),
        t_location(
            REF(s),                                                 -- Contenu : Les Chroniques de Brume
            t_dates(TRUNC(SYSDATE) - 1, TRUNC(SYSDATE) + 6),        -- Location en cours
            2                                                       -- Numéro de saison
        )
    ),
    t_abonnement(                                                   -- Abonnement effectif
        1,                                                          -- Formule Basique
        t_dates(TRUNC(SYSDATE) - 30, TRUNC(SYSDATE) + 30)           -- Dates de validité
    )
FROM Contenu fc, Contenu sv, Contenu s
WHERE fc.id_contenu = 1 AND sv.id_contenu = 2 AND s.id_contenu = 3;

INSERT INTO CompteClient (
    id_client, prenom, nom, adresse, mail, telephone, hash_mdp,
    achats, locations, abonnement
)
VALUES (
    3,                                                              -- ID
    'Alex',                                                         -- Prénom
    'Bernard',                                                      -- Nom
    '3 rue des Tests, Poitiers',                                    -- Adresse
    'alex.bernard@example.test',                                    -- Mail
    '0600000003',                                                   -- Téléphone
    'test_3',                                                       -- Mot de passe
    achat_list(),                                                   -- Aucun achat
    location_list(),                                                -- Aucune location
    t_abonnement(                                                   -- Abonnement effectif
        3,                                                          -- Formule VIP
        t_dates(TRUNC(SYSDATE) - 30, TRUNC(SYSDATE) + 30)           -- Dates de validité
    )
);

INSERT INTO CompteClient (
    id_client, prenom, nom, adresse, mail, telephone, hash_mdp,
    achats, locations, abonnement
)
SELECT
    4,                                                              -- ID
    'Léa',                                                          -- Prénom
    'Petit',                                                        -- Nom
    '4 rue des Tests, Poitiers',                                    -- Adresse
    'lea.petit@example.test',                                       -- Mail
    '0600000004',                                                   -- Téléphone
    'test_4',                                                       -- Mot de passe
    achat_list(                                                     -- Achats
        t_achat(
            REF(c),                                                 -- Contenu : Une soirée en scène
            NULL                                                    -- Contenu entier
        )
    ),
    location_list(),                                                -- Aucune location
    NULL                                                            -- Aucun abonnement
FROM Contenu c
WHERE c.id_contenu = 5;

COMMIT;