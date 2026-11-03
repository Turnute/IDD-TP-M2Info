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

-- Compléter ici


-- ------------------------------------------------------------------------------------------------
-- A8 — Calculer la somme perçue si tous les exemplaires du livre d'ISBN 1 étaient
-- rendus aujourd'hui.

-- Compléter ici


-- ------------------------------------------------------------------------------------------------
-- A9 — Proposer une extension de la base relationnelle-objet couvrant l'ensemble du
-- cahier des charges (plusieurs auteurs par livre, auteurs éventuellement lauréats du
-- prix Goncourt, personnes décrites aussi par leur père, etc.).

-- Compléter ici


-- ------------------------------------------------------------------------------------------------
-- A10 — Proposer des requêtes montrant l'intérêt de l'extension précédente.
-- Exemple donné : rechercher tous les livres écrits par un auteur particulier.

-- Compléter ici


-- ================================================================================================
-- EXERCICE B — CONCEPTION D'UNE PLATEFORME DE VOD EN RELATIONNEL-OBJET
-- Modéliser les contenus vidéo, les comptes clients, les achats, les locations
-- et les abonnements à partir du cahier des charges fourni.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- B1 — Proposer une conception relationnelle-objet pour le cahier des charges VOD.
-- ------------------------------------------------------------------------------------------------

-- Compléter ici


-- ------------------------------------------------------------------------------------------------
-- B2 — Écrire les requêtes SQL demandées pour la conception proposée en B1.
-- Livrable mentionné dans le sujet : script requete.sql.
-- ------------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- B2.1 — Lister par ordre alphabétique les titres des contenus dont le thème principal
-- comprend le mot « Anime » ou « Fantasy ».

-- Compléter ici


-- ------------------------------------------------------------------------------------------------
-- B2.2 — Lister les titres et les thèmes des contenus empruntés par Dupont entre
-- janvier et mars 2022.

-- Compléter ici


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
