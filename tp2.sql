-- ================================================================================================
-- TP2 IDD
-- Vincent TOURENNE
-- ================================================================================================


-- ================================================================================================
-- EXERCICE A — DÉCOUVERTE DU MODÈLE OBJET-RELATIONNEL
-- Modéliser une bibliothèque : livres, exemplaires, emprunts, personnes et auteurs.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- NOTIONS DE TYPES ET MÉTHODES
-- ------------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- A1 — Créer un type t_personne possédant un nom et un prénom.

CREATE OR REPLACE TYPE t_personne AS OBJECT (
    prenom varchar(20),
    nom varchar(20)
);
/

-- ------------------------------------------------------------------------------------------------
-- A2 — Créer un type t_emprunt possédant un emprunteur (t_personne), une date d'emprunt
-- et un prix à payer par jour.

CREATE OR REPLACE TYPE t_emprunt AS OBJECT (
    emprunteur t_personne,  -- référence à l'emprunteur
    date_emprunt date,      -- date d'emprunt
    prix_jour number(5,2)   -- coût journalier en euros,centimes.
);
/

-- ------------------------------------------------------------------------------------------------
-- A3 — Ajouter à t_emprunt une méthode calculant le prix à payer si le livre était rendu
-- aujourd'hui. La méthode sera testée ultérieurement.

CREATE OR REPLACE TYPE t_emprunt AS OBJECT (
    emprunteur t_personne,  -- référence à l'emprunteur
    date_emprunt date,      -- date d'emprunt
    prix_jour number(5,2),  -- coût journalier en euros,centimes.

    MEMBER FUNCTION cout_tot RETURN NUMBER,    -- renvoie le coût total depuis l'emprunt
    PRAGMA RESTRICT_REFERENCES(cout_tot, WNDS)  -- permet d’utiliser cette méthode dans une requête
);
/


CREATE OR REPLACE TYPE BODY t_emprunt AS
    MEMBER FUNCTION cout_tot RETURN NUMBER IS
        nb_jours NUMBER;
    BEGIN
        nb_jours := CEIL(SYSDATE - date_emprunt);   -- différence arrondie
        RETURN nb_jours * prix_jour;
    END cout_tot;
END;
/


-- ------------------------------------------------------------------------------------------------
-- A4 — Créer un type t_exemplaire possédant un prix et un emprunt.

CREATE OR REPLACE TYPE t_exemplaire AS OBJECT (
    prix number(5,2),
    emprunt t_emprunt
);
/


-- ------------------------------------------------------------------------------------------------
-- NOTIONS DE COLLECTIONS
-- ------------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- A5 — Créer une table Livre ayant pour clé primaire un numéro ISBN, et pour attributs
-- un titre et une liste d'exemplaires.

DROP TABLE Livre;
DROP TYPE ex_list;

-- Création du type collection
CREATE TYPE ex_list AS TABLE OF t_exemplaire;
/

-- Création de la table
CREATE TABLE Livre
(
    ISBN INTEGER NOT NULL,
    titre VARCHAR2(50),
    exemplaires ex_list,    -- attribut type_collection
    CONSTRAINT PK_Livre PRIMARY KEY (ISBN)
)
NESTED TABLE exemplaires STORE AS Exemplaire; -- table imbriquée

-- ------------------------------------------------------------------------------------------------
-- A6 — Peupler la table Livre avec quelques livres.

DELETE FROM Livre; -- Vide la table

INSERT INTO Livre (ISBN, titre, exemplaires)
VALUES (
    1,              -- ISBN
    'Le Hobbit',    -- Titre
    ex_list(        -- Liste d'exemplaires
        t_exemplaire(15.50, NULL),          -- coûte 15,5€, n'est pas emprunté
        t_exemplaire(12.00, t_emprunt(      -- coûte 12€, est emprunté...
            t_personne('Jean', 'Dupont'),   -- par Jean Dupont
            SYSDATE - 5,                    -- Il y a 5 jours
            0.50                            -- A un prix journalier de 50 centimes
        ))
    )
);

INSERT INTO Livre (ISBN, titre, exemplaires)
VALUES (
    2,
    'Rhinocéros',
    ex_list(
        t_exemplaire(22.00, NULL),
        t_exemplaire(22.00, t_emprunt(
            t_personne('Marie', 'Martin'),
            SYSDATE - 10,
            1.00
        )),
        t_exemplaire(18.50, NULL)
    )
);

INSERT INTO Livre (ISBN, titre, exemplaires)
VALUES (
    3,
    'Ducobu',
    ex_list(
        t_exemplaire(30.00, t_emprunt(
            t_personne('Lucas', 'Bernard'),
            SYSDATE - 3,
            0.75
        )),
        t_exemplaire(28.00, NULL)
    )
);

SELECT * FROM Livre;

-- Résultat :
-- ISBN TITRE        EXEMPLAIRES                                                                                                                                                                          
-- ---- ------------ ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ 
-- 1    Le Hobbit    [{"prix":15.5,"emprunt":null},{"prix":12,"emprunt":{"emprunteur":{"prenom":"Jean","nom":"Dupont"},"date_emprunt":"2026-10-29T16:27:56Z","prix_jour":0.5}}]                           
-- 2    Rhinocéros   [{"prix":22,"emprunt":null},{"prix":22,"emprunt":{"emprunteur":{"prenom":"Marie","nom":"Martin"},"date_emprunt":"2026-10-24T16:27:56Z","prix_jour":1}},{"prix":18.5,"emprunt":null}] 
-- 3    Ducobu       [{"prix":30,"emprunt":{"emprunteur":{"prenom":"Lucas","nom":"Bernard"},"date_emprunt":"2026-10-31T16:27:56Z","prix_jour":0.75}},{"prix":28,"emprunt":null}]                          


-- ------------------------------------------------------------------------------------------------
-- REQUÊTES RELATIONNELLES-OBJETS
-- ------------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- A7 — Calculer le prix moyen des exemplaires du livre d'ISBN 1.

-- Deux livres enregistrés, de prix 15.5 et 12. Moyenne attendue de 13.75.

SELECT SUM(e.prix)/COUNT(*) prix_moyen
FROM Livre l, TABLE(l.exemplaires) e    -- TABLE() permet de désimbriquer la collection !
WHERE ISBN = 1;


-- Résultat :
-- PRIX_MOYEN 
-- ---------- 
-- 13.75      


-- ------------------------------------------------------------------------------------------------
-- A8 — Calculer la somme perçue si tous les exemplaires du livre d'ISBN 1 étaient
-- rendus aujourd'hui.

-- Ne concerne qu'un seul livre (le premier n'est pas emprunté) de coût 12 avec un intérêt de 0.5 
-- par jour, emprunté il y a 5 jours. Somme attendue de 14.5.

SELECT SUM(e.prix+e.emprunt.cout_tot()) somme_tot -- La méthode cout_tot appartient à emprunt.
FROM Livre l, TABLE(l.exemplaires) e
WHERE ISBN = 1;

-- Résultat :
-- SOMME_TOT 
-- --------- 
-- 14.5        

-- On peut tester avec deux livres empruntés. On insère un exemplaire supplémentaire :
INSERT INTO TABLE(
    SELECT l.exemplaires
    FROM Livre l
    WHERE l.ISBN = 1
)
VALUES (
    t_exemplaire(20.00, t_emprunt(
        t_personne('Alice', 'Durand'),
        SYSDATE - 2,
        1.00
    ))
);

-- On vérifie la nouvelle somme (14.5 + (20+1*2) = 36.5) :
SELECT SUM(e.prix + e.emprunt.cout_tot()) somme_tot
FROM Livre l, TABLE(l.exemplaires) e
WHERE l.ISBN = 1;

-- Résultat :
-- SOMME_TOT 
-- --------- 
-- 36.5        


-- ------------------------------------------------------------------------------------------------
-- A9 — Proposer une extension de la base relationnelle-objet couvrant l'ensemble du
-- cahier des charges.

-- Changements à effectuer :
-- 1. Une personne doit avoir une référence vers son père, une autre personne.
-- 2. Création d'un type auteur : personne + si elle a le prix Goncourt ou non.
-- 3. Un livre doit avoir un ou plusieurs auteurs de définis (collection, comme pour les exemplaires).

-- 1. PERSONNE : REFERENCE VERS PERE

-- ALTER plutôt qu'un DROP OR REPLACE : le type t_personne existe déjà et a des dépendances.
ALTER TYPE t_personne
ADD ATTRIBUTE (pere REF t_personne)
CASCADE;
/

-- Besoin d'avoir une table personne pour que pere puisse pointer qq part
CREATE TABLE Personnes OF t_personne;


-- Enregistrement et test
INSERT INTO Personnes VALUES (t_personne('Jean', 'Dupont', NULL));

INSERT INTO Personnes
SELECT t_personne('Jean-Jean', 'Dupont', REF(p))
FROM Personnes p
WHERE p.prenom = 'Jean' AND p.nom = 'Dupont';

SELECT p.prenom, p.nom,
       p.pere.prenom AS prenom_pere,
       p.pere.nom AS nom_pere
FROM Personnes p;


-- Résultat attendu :
-- PRENOM               NOM                  PRENOM_PERE          NOM_PERE            
-- -------------------- -------------------- -------------------- --------------------
-- Jean                 Dupont                                                        
-- Jean-Jean            Dupont               Jean                 Dupont

-- Ajout de personnes qui seront des auteurs
INSERT INTO Personnes VALUES (t_personne('J.R.R', 'Tolkien', NULL));
INSERT INTO Personnes VALUES (t_personne('Moi', 'Même', NULL));

INSERT INTO Personnes
SELECT t_personne('Mon', 'Fils', REF(p))
FROM Personnes p
WHERE p.prenom = 'Moi' AND p.nom = 'Même';


-- 2. TYPE AUTEUR

-- Création du type
CREATE TYPE t_auteur AS OBJECT (
    personne REF t_personne,    -- pointe vers une personne existante
    goncourt CHAR(1)            -- O pour oui, N pour non
);
/


-- 3. AJOUT DU TYPE AUTEUR EN COLLECTION A LA TABLE LIVRE

-- Collection
CREATE TYPE auteur_list AS TABLE OF t_auteur;
/

-- Ajout de la collection à Livre
ALTER TABLE Livre
ADD (auteurs auteur_list)
NESTED TABLE auteurs STORE AS AuteursLivre;
/

-- Trigger sur la table livre, on doit forcément avoir au moins un auteur à l'insertion
-- (On ne gère pas ici les livres exemples déjà insérés)
CREATE OR REPLACE TRIGGER no_empty_auteur
BEFORE INSERT OR UPDATE OF auteurs ON Livre
FOR EACH ROW
DECLARE
    liste auteur_list;
BEGIN
    liste := :NEW.auteurs;
    IF liste IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Le livre doit avoir au moins un auteur !');
    ELSIF liste.COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Le livre doit avoir au moins un auteur !');
    END IF;
END;
/

-- Test :
-- Update d'un livre existant
-- On récupère une personne de la table personne comme auteur
UPDATE Livre l
SET auteurs = (
    SELECT auteur_list(t_auteur(REF(p), 'N'))
    FROM Personnes p
    WHERE p.prenom = 'J.R.R' AND p.nom = 'Tolkien'
)
WHERE l.ISBN = 1;

-- Insertion d'un livre sans auteur
INSERT INTO Livre (ISBN, titre, exemplaires)
VALUES (
    4,
    'MonLivreAMoi',
    ex_list(
        t_exemplaire(100.00, NULL),
        t_exemplaire(0.00, NULL)
    )
);
-- Erreur SQL : ORA-20001: Le livre inséré doit avoir au moins un auteur !

-- Insertion d'un livre avec plusieurs auteurs
INSERT INTO Livre (ISBN, titre, exemplaires, auteurs)
SELECT 4,
       'MonLivreAMoi',
       ex_list(t_exemplaire(100.00, NULL), t_exemplaire(0.00, NULL)),
       auteur_list(
           t_auteur(REF(p), 'O'),
           t_auteur(REF(f), 'N')
       )
FROM Personnes p, Personnes f
WHERE p.prenom = 'Moi' AND p.nom = 'Même' AND f.prenom = 'Mon' AND f.nom = 'Fils';

SELECT 
    l.ISBN, l.titre,
    a.personne.prenom AS prenom_auteur,
    a.personne.nom AS nom_auteur,
    a.goncourt
FROM Livre l, TABLE(l.auteurs) a;

-- Résultat attendu :
--       ISBN TITRE                                              PRENOM_AUTEUR        NOM_AUTEUR           G
-- ---------- -------------------------------------------------- -------------------- -------------------- -
--          1 Le Hobbit                                          J.R.R                Tolkien              N
--          4 MonLivreAMoi                                       Moi                  Même                 O
--          4 MonLivreAMoi                                       Mon                  Fils                 N


-- ------------------------------------------------------------------------------------------------
-- A10 — Proposer des requêtes montrant l'intérêt de l'extension précédente.

-- Exemple simple : récupérer tous les livres écris par Mon Fils

-- Update simple pour retourner plusieurs livres
UPDATE Livre l
SET auteurs = (
    SELECT auteur_list(t_auteur(REF(f), 'N'))
    FROM Personnes f
    WHERE f.prenom = 'Mon' AND f.nom = 'Fils'
)
WHERE l.ISBN = 3;

-- Requête :
SELECT
    l.ISBN,
    l.titre,
    a.personne.prenom AS prenom_auteur,
    a.personne.nom AS nom_auteur
FROM Livre l, TABLE(l.auteurs) a
WHERE a.personne.prenom = 'Mon' AND a.personne.nom = 'Fils';

-- ------------------------------------------------------------------------------------------------
-- Nettoyage de l'exercice A
DROP TABLE Livre PURGE;
DROP TABLE Personnes PURGE;

DROP TYPE auteur_list;
DROP TYPE ex_list;
DROP TYPE t_auteur;
DROP TYPE t_exemplaire;
DROP TYPE t_emprunt;
DROP TYPE t_personne;

-- ================================================================================================
-- EXERCICE B — CONCEPTION D'UNE PLATEFORME DE VOD EN RELATIONNEL-OBJET
-- Modéliser les contenus vidéo, les comptes clients, les achats, les locations
-- et les abonnements à partir du cahier des charges fourni.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- B1 — Proposer une conception relationnelle-objet pour le cahier des charges VOD.
-- ------------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- EXPLICATION DE LA PROPOSITION

-- On fait un type t_personne(prénom, nom), utile pour un peu tout
-- Table Personne pour stocker toutes les personnes enregistrées dans la bd (pas les clients : les réalisateurs, acteurs...)

-- type t_dates(date_debut, date_fin), utile pour location et abonnement

-- On utilise un mécanisme d'héritage pour le contenu :
-- Classe CONTENU de base avec id(pkey), titre, desc, thème, mots clés (collection varchar), réalisateurs (collection t_personne), année et pays
-- Héritage en :
-- - cinema : duree, acteurs (collection t_personne), scenaristes (collection t_personne)
-- - serie : collection saisons (type t_saison(num, nb_ep, desc)) + nombre (automatisé par trigger)
-- - jeunesse : duree, scenaristes (collection t_personne), compositeur (collection t_personne)
-- - divertissement : duree, metteurs en scene (collection t_personne), interprètes (collection t_personne)

--  → table Contenu of type t_contenu avec tout ça

-- type t_location(ref t_contenu, t_dates, num_saison (peut être null))
-- type t_achat(ref t_contenu, num_saison)

-- Table modèle d'abonnement : duree max d'emprunt pour les 4 types (max_cine, max_series...), nb max total d'emprunts, prix mensuel, nom formule, id

-- type t_abonnement(id_abonnement, t_dates)

-- Table CompteClient :
-- - id (pkey), nom, prenom, adresse, mail, telephone, mdp,
-- - contenus achetés (collection t_achat),
-- - contenus loués (collection t_location),
-- - abonnement t_abonnement (peut être null) (foreign key)

-- TODO : petit diagramme de classe / base de données en texte pour expliquer tout ça


------------------------------------------------------------------------------------------------
-- CREATION DE LA STRUCTURE DE LA BASE DE DONNEES

-- TYPES BASIQUES --------------------------------------------------------------

-- Représente une personne en bd (pas un client)
CREATE OR REPLACE TYPE t_personne AS OBJECT (
    id_personne NUMBER,
    prenom VARCHAR(20),
    nom VARCHAR(20)
);
/

CREATE TABLE Personne OF t_personne (
    CONSTRAINT pk_personne PRIMARY KEY (id_personne)
);

-- Collection de reférences aux personnes
CREATE TYPE personnes_refs AS TABLE OF REF t_personne;
/

-- Représente une plage de dates (début et fin), utile notamment à la location
-- et à l'abonnement
CREATE OR REPLACE TYPE t_dates AS OBJECT (
    date_debut DATE,
    date_fin DATE
);
/

-- CONTENU ---------------------------------------------------------------------

-- Collection de mots clés d'un contenu
CREATE TYPE mots_cles_list AS TABLE OF VARCHAR(20);
/

-- Représente un contenu quelconque
CREATE OR REPLACE TYPE t_contenu AS OBJECT (
    id_contenu NUMBER, -- TODO : en faire une pkey ?
    titre VARCHAR(100),
    description VARCHAR(300),
    theme VARCHAR(50),
    mots_cles mots_cles_list,
    realisateurs personnes_refs,
    annee NUMBER(4),
    pays VARCHAR(50)
) NOT FINAL;
/

-- Représente un film (héritage de contenu)
CREATE TYPE t_cinema UNDER t_contenu (
    duree NUMBER,               -- en minutes
    acteurs personnes_refs,     -- collection d'acteurs
    scenaristes personnes_refs  -- collection de scénaristes
);
/

-- Représente une saison d'une série
CREATE TYPE t_saison AS OBJECT (
    numero NUMBER,
    nb_episodes NUMBER,
    description VARCHAR(300)
);
/

-- Collection de saisons
CREATE TYPE saisons_list AS TABLE OF t_saison;
/

-- Représente une série (héritage de contenu)
CREATE TYPE t_serie UNDER t_contenu (
    saisons saisons_list
);
/

-- Représente un contenu de jeunesse (héritage de contenu)
CREATE TYPE t_jeunesse UNDER t_contenu (
    duree NUMBER,
    scenaristes personnes_refs,
    compositeurs personnes_refs
);
/

-- Représente un divertissement (héritage de contenu)
CREATE TYPE t_divertissement UNDER t_contenu (
    duree NUMBER,
    metteurs_en_scene personnes_refs,
    interpretes personnes_refs
);
/

-- Table des contenus : stocke des contenus de type t_contenu ou hérités
CREATE TABLE Contenu OF t_contenu (
    CONSTRAINT pk_contenu PRIMARY KEY (id_contenu)
)
NESTED TABLE mots_cles STORE AS MotsCles_Stockage
NESTED TABLE realisateurs STORE AS Real_Stockage
NESTED TABLE TREAT(OBJECT_VALUE AS t_cinema).acteurs STORE AS CineActeurs_Stockage
NESTED TABLE TREAT(OBJECT_VALUE AS t_cinema).scenaristes STORE AS CineScenaristes_Stockage
NESTED TABLE TREAT(OBJECT_VALUE AS t_serie).saisons STORE AS Saisons_Stockage
NESTED TABLE TREAT(OBJECT_VALUE AS t_jeunesse).scenaristes STORE AS JeunScenaristes_Stockage
NESTED TABLE TREAT(OBJECT_VALUE AS t_jeunesse).compositeurs STORE AS JeunCompositeurs_Stockage
NESTED TABLE TREAT(OBJECT_VALUE AS t_divertissement).metteurs_en_scene STORE AS DivMetteurs_Stockage
NESTED TABLE TREAT(OBJECT_VALUE AS t_divertissement).interpretes STORE AS DivInterpretes_Stockage;


-- FORMULES D'ABONNEMENT --------------------------------------------------------

-- Stocke les différents modèles d'abonnement possibles
CREATE TABLE Abonnement (
    id_abonnement NUMBER PRIMARY KEY,
    nom_formule VARCHAR(20) NOT NULL,
    prix_mensuel DECIMAL(19, 4) NOT NULL,
    nb_locations_max NUMBER NOT NULL,
    duree_cinema NUMBER NOT NULL,
    duree_serie NUMBER NOT NULL,
    duree_jeunesse NUMBER NOT NULL,
    duree_divertissement NUMBER NOT NULL
);


-- Représente un abonnement effectif
CREATE OR REPLACE TYPE t_abonnement AS OBJECT (
    id_abonnement NUMBER,   -- type d'abonnement
    dates t_dates           -- duree de l'abonnement
);
/

-- LOCATIONS ET ACHATS --------------------------------------------------------

-- Représente une location
CREATE OR REPLACE TYPE t_location AS OBJECT (
    contenu REF t_contenu,
    dates t_dates,
    num_saison NUMBER -- Si on loue qu'une saison d'une série
);
/

-- Représente un achat
CREATE OR REPLACE TYPE t_achat AS OBJECT (
    contenu REF t_contenu,
    num_saison NUMBER
);
/

-- Collection d'achats
CREATE TYPE achat_list AS TABLE OF t_achat;
/
-- Collection de locations
CREATE TYPE location_list AS TABLE OF t_location;
/

-- COMPTES CLIENTS ------------------------------------------------------------

CREATE TABLE CompteClient (
    id_client NUMBER PRIMARY KEY,
    prenom VARCHAR(20),
    nom VARCHAR(20),
    adresse VARCHAR(200),
    mail VARCHAR(50),
    telephone VARCHAR(20),
    hash_mdp VARCHAR(20), -- Pour ce TP, on fait comme si c'était un mdp sécurisé
    achats achat_list,
    locations location_list,
    abonnement t_abonnement,
    CONSTRAINT fk_client_formule
        FOREIGN KEY (abonnement.id_abonnement)
        REFERENCES Abonnement (id_abonnement)
)
NESTED TABLE achats STORE AS Achats_Stockage
NESTED TABLE locations STORE AS Locations_Stockage;


------------------------------------------------------------------------------------------------
-- REMPLISSAGE POUR LES EXERCICES SUIVANTS

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
        1,                                                          -- Formule Basique
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
    'test_2',                                                -- Mot de passe
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
        2,                                                          -- Formule Prénium
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
    'test_3',                                                -- Mot de passe
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
    'test_4',                                                -- Mot de passe
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


-- ------------------------------------------------------------------------------------------------
-- B2 — Écrire les requêtes SQL demandées pour la conception proposée en B1.
-- ------------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- B2.1 — Lister par ordre alphabétique les titres des contenus dont le thème principal
-- comprend le mot « Anime » ou « Fantasy ».

SELECT Titre
FROM Contenu
WHERE Theme LIKE '%Anime%' OR Theme LIKE '%Fantasy%'
ORDER BY Titre ASC;
/

-- Résultats attendus :
-- TITRE                                                                                               
-- ----------------------------
-- La Forêt des lucioles
-- Les Chroniques de Brume
-- Les Petits Astronautes


-- ------------------------------------------------------------------------------------------------
-- B2.2 — Lister les titres et les thèmes des contenus empruntés par Dupont entre
-- janvier et mars 2022.

-- SELECT c.Titre, c.Theme
-- FROM CompteClient cc, cc.locations.contenu c
-- WHERE cc.Nom = 'Dupont' AND
--     cc.dates.date_debut > "janvier 2022" AND
--     cc.dates.date_fin < "mars 2022"
-- ;
-- /


-- ------------------------------------------------------------------------------------------------
-- B2.3 — Donner, pour chaque abonné, son nombre de contenus empruntés et le nombre
-- qu'il peut encore emprunter compte tenu de son abonnement.

-- Compléter ici


-- ------------------------------------------------------------------------------------------------
-- B2.4 — Lister sans doublon les acteurs ayant joué dans un film réalisé par
-- David Fincher, avec le nombre de films tournés avec ce réalisateur pour chacun.

-- Compléter ici


-- ------------------------------------------------------------------------------------------------
-- B2.5 — Trouver le ou les réalisateurs ayant réalisé le plus de contenus.

-- Compléter ici

-- ------------------------------------------------------------------------------------------------
-- B3 — Compléter avec d'autres requêtes utilisant les concepts relationnels-objets.
-- ------------------------------------------------------------------------------------------------

-- Nombre de saisons d'une série
