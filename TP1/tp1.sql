-- ================================================================================================
-- TP1 IDD
-- Vincent TOURENNE
-- ================================================================================================


-- ================================================================================================
-- EXERCICE 1 — REQUÊTES ET CONTRAINTES SUR LA BASE VENTES
-- Gestion des clients, produits, commandes et livraisons : requêtes, suppressions et contraintes.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- QUESTION 1 — INTERROGATION ET MODIFICATION DES DONNÉES
-- ------------------------------------------------------------------------------------------------

-- E1Q1.1 — Lister les produits dont la quantité totale commandée depuis le 05/07/2021
-- est d’au moins 10.

SELECT lc.noproduit, SUM(lc.quantitecommande) somme
FROM lignecommande lc, commande c
WHERE lc.nocommande = c.nocommande
    AND c.datecommande >= TO_DATE('05/07/2021', 'DD/MM/YYYY')
GROUP BY lc.noproduit
HAVING SUM(lc.quantitecommande) >= 10;


-- ------------------------------------------------------------------------------------------------
-- E1Q1.2 — Lister les commandes sauf les 3 premières et les 3 dernières par ordre de date.

SET SERVEROUTPUT ON;

DECLARE
    nb_cmd INTEGER;
    i INTEGER := 1;
BEGIN
    SELECT COUNT(*) INTO nb_cmd FROM commande;

    FOR line IN (SELECT * FROM commande ORDER BY datecommande ASC) LOOP
        IF i > 3 AND i < nb_cmd - 2 THEN
            DBMS_OUTPUT.PUT_LINE(line.nocommande || ' ' || line.datecommande);
        END IF;
        i := i + 1;
    END LOOP;
END;


-- ------------------------------------------------------------------------------------------------
-- E1Q1.3 — Donner la quantité commandée et la quantité en attente pour chaque produit
-- de chaque commande.

SELECT lc.nocommande, lc.noproduit, lc.quantitecommande,
    lc.quantitecommande - NVL(SUM(dl.quantitelivree), 0) quantiteenattente
    -- NVL remplace NULL par 0
FROM lignecommande lc
LEFT OUTER JOIN detaillivraison dl ON lc.nocommande = dl.nocommande AND lc.noproduit = dl.noproduit
    -- car on veut garder toutes les commandes même sans livraisons
GROUP BY lc.noproduit, lc.nocommande, lc.quantitecommande;
    -- Une ligne est identifiée par le couple (nocommande, noproduit).


-- ------------------------------------------------------------------------------------------------
-- E1Q1.4 — Supprimer les produits qui n’ont jamais été commandés

DELETE FROM produit
WHERE produit.noproduit NOT IN (SELECT lignecommande.noproduit FROM lignecommande);

SELECT * FROM produit;


-- ------------------------------------------------------------------------------------------------
-- E1Q1.5 — Supprimer un client donné et ses données associées

SET SERVEROUTPUT ON;

-- Bloquer les tables pour éviter des modifications d'autrui
LOCK TABLE client IN SHARE MODE;
LOCK TABLE livraison IN SHARE MODE;
LOCK TABLE detaillivraison IN SHARE MODE;
LOCK TABLE commande IN SHARE MODE;
LOCK TABLE lignecommande IN SHARE MODE;

DECLARE
    delete_client INTEGER := 1; -- numéro du client à supprimer

    -- curseur à parcourir : requête renvoyant tous les numéros de livraison
    -- associés au client
    CURSOR c1 IS
        SELECT client.noclient, commande.nocommande, detaillivraison.nolivraison
        FROM client
        JOIN commande ON client.noclient = commande.noclient
        JOIN detaillivraison ON detaillivraison.nocommande = commande.nocommande
        WHERE client.noclient = delete_client
        GROUP BY client.noclient, commande.nocommande, detaillivraison.nolivraison;

    -- curseur à parcourir : requête ne renvoyant que les numéros de commande
    -- associés au client
    CURSOR c2 IS
        SELECT client.noclient, commande.nocommande
        FROM client
        JOIN commande ON client.noclient = commande.noclient
        WHERE client.noclient = delete_client;
BEGIN
    -- Boucle 1 : suppression de chaque livraison associée au client
    FOR i IN c1 LOOP
        -- On supprime detaillivraison en premier car elle est "enfant" de livraison
        DELETE FROM detaillivraison WHERE detaillivraison.nolivraison = i.nolivraison;
        DELETE FROM livraison WHERE livraison.nolivraison = i.nolivraison;
    END LOOP;

    -- Boucle 2 : suppression de chaque commande associée au client
    FOR i IN c2 LOOP
        -- On supprime lignecommande en premier car elle est "enfant" de commande
        DELETE FROM lignecommande WHERE lignecommande.nocommande = i.nocommande;
        DELETE FROM commande WHERE commande.nocommande = i.nocommande;
    END LOOP;

    -- Enfin, suppression du client
    DELETE FROM client WHERE noclient = delete_client;

    -- Commit et gestion des exceptions
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(SQLERRM);
        ROLLBACK;
END;


-- ------------------------------------------------------------------------------------------------
-- QUESTION 2 — CONTRAINTES ET DÉCLENCHEURS
-- ------------------------------------------------------------------------------------------------

-- E1Q2.1 — Limiter la quantité commandée à 5 pour les produits de numéro supérieur à 10000.

-- On ne manipule qu’une seule table avec un simple check booléen, pas besoin de PL/SQL :
-- on va faire ça en contrainte SQL

ALTER TABLE lignecommande ADD CONSTRAINT ex121
    CHECK (
        -- représentation booléenne de la condition donnée
        noproduit <= 10000 OR quantitecommande <= 5
    );

-- TESTS
INSERT INTO produit (noproduit, prixunitaire) VALUES (10500, 0);
INSERT INTO produit (noproduit, prixunitaire) VALUES (11000, 0);
INSERT INTO produit (noproduit, prixunitaire) VALUES (9000, 0);

INSERT INTO lignecommande VALUES (5, 10500, 6); -- fail attendu
INSERT INTO lignecommande VALUES (5, 11000, 4); -- réussite attendue
INSERT INTO lignecommande VALUES (5, 9000, 10); -- réussite attendue

SELECT * FROM lignecommande WHERE nocommande = 5 AND noproduit >= 9000;


-- ------------------------------------------------------------------------------------------------
-- E1Q2.2 — Calculer et maintenir le total des commandes ; interdire les modifications
-- des lignes de commande et des prix unitaires.

ALTER TABLE commande
    ADD totalcommande NUMBER(38, 2) DEFAULT 0 NOT NULL;

-- Peupler la nouvelle colonne
UPDATE commande c
SET totalcommande = (
    SELECT NVL(SUM(lc.quantitecommande * p.prixunitaire), 0)
    FROM lignecommande lc, produit p
    WHERE c.nocommande = lc.nocommande AND p.noproduit = lc.noproduit
);

-- update automatique de commande si insertion ou supression sur lignecommande
CREATE OR REPLACE TRIGGER update_commandes
AFTER INSERT OR DELETE ON lignecommande
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        UPDATE commande c
        SET c.totalcommande = c.totalcommande + (:NEW.quantitecommande *
            (
                SELECT p.prixunitaire
                FROM produit p
                WHERE p.noproduit = :NEW.noproduit
            )
        )
        WHERE c.nocommande = :NEW.nocommande;
    END IF;

    IF DELETING THEN
        UPDATE commande c
        SET c.totalcommande = c.totalcommande - (:OLD.quantitecommande *
            (
                SELECT p.prixunitaire
                FROM produit p
                WHERE p.noproduit = :OLD.noproduit
            )
        )
        WHERE c.nocommande = :OLD.nocommande;
    END IF;
END;
/
-- / : sépare les triggers

-- interdit les mises à jours de lignecommande existants
CREATE OR REPLACE TRIGGER no_update_lignecommande
BEFORE UPDATE ON lignecommande
BEGIN
    RAISE_APPLICATION_ERROR(-20001, 'Modification de lignecommande interdite');
END;
/

-- interdit les mises à jour de prix de produits existants
CREATE OR REPLACE TRIGGER no_update_prix
BEFORE UPDATE OF prixunitaire ON produit
BEGIN
    RAISE_APPLICATION_ERROR(-20002, 'Modification de prixunitaire interdite');
END;
/

-- TESTS
SELECT totalcommande FROM commande WHERE nocommande = 1; -- attendu : 750
INSERT INTO lignecommande VALUES (1, 3, 2); -- succès
SELECT totalcommande FROM commande WHERE nocommande = 1; -- attendu : 950
DELETE FROM lignecommande WHERE nocommande = 1 AND noproduit = 3; -- succès
SELECT totalcommande FROM commande WHERE nocommande = 1; -- attendu : 750
UPDATE lignecommande SET quantitecommande = 0 WHERE nocommande = 6; -- fail
UPDATE produit SET prixunitaire = 0 WHERE noproduit = 1; -- fail


-- ------------------------------------------------------------------------------------------------
-- E1Q2.3 — Interdire la diminution du prix unitaire d’un produit.

DROP TRIGGER no_update_prix;

CREATE OR REPLACE TRIGGER no_dim_prix
BEFORE UPDATE OF prixunitaire ON produit
FOR EACH ROW
BEGIN
    IF :NEW.prixunitaire < :OLD.prixunitaire THEN
        RAISE_APPLICATION_ERROR(-20003, 'DIMINUTION DE PRIX NON AUTORISEE');
    END IF;
END;
/

UPDATE produit SET prixunitaire = (SELECT prixunitaire FROM produit WHERE noproduit = 1) - 5
WHERE noproduit = 1; -- fail


-- ------------------------------------------------------------------------------------------------
-- E1Q2.4 — À l’insertion, empêcher une livraison antérieure à la commande correspondante.

CREATE OR REPLACE TRIGGER check_dates
BEFORE INSERT ON detaillivraison
-- car est fille de livraison, c'est là qu'on renseigne et connait la commande et donc datecommande,
-- on peut pas y accéder depuis livraison
FOR EACH ROW
DECLARE
    date_commande commande.datecommande%TYPE;
    date_livraison livraison.datelivraison%TYPE;
BEGIN
    SELECT datelivraison INTO date_livraison
    FROM livraison
    WHERE nolivraison = :NEW.nolivraison;

    SELECT datecommande INTO date_commande
    FROM commande
    WHERE nocommande = :NEW.nocommande;

    IF date_livraison < date_commande THEN
        RAISE_APPLICATION_ERROR(-20004, 'La livraison ne peut pas preceder la commande');
    END IF;
END;
/

-- TESTS
INSERT INTO livraison VALUES (42, TO_DATE('11/10/2019', 'DD/MM/YYYY'));
INSERT INTO detaillivraison VALUES (42, 9, 5, 46);


-- ================================================================================================
-- EXERCICE 2 — ARBRES BINAIRES DE RECHERCHE EN BASE DE DONNÉES
-- Manipuler un ABR stocké dans la table abr (id, valeur, idfg, idfd),
-- puis contrôler ses contraintes.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- QUESTION 1 — CONSULTATION ET CONSTRUCTION D’UN ARBRE
-- ------------------------------------------------------------------------------------------------

-- E2Q1.1 — Compter le nombre total de nœuds de l’arbre.

SELECT COUNT(*) FROM abr;


-- ------------------------------------------------------------------------------------------------
-- E2Q1.2 — Trouver la plus petite valeur enregistrée dans l’arbre.

SELECT MIN(valeur) FROM abr;


-- ------------------------------------------------------------------------------------------------
-- E2Q1.3 — Calculer la hauteur de l’arbre.

CREATE OR REPLACE FUNCTION hauteur(monid INTEGER)
RETURN INTEGER
AS
    monidfg INTEGER;
    monidfd INTEGER; -- variables locales
    hg INTEGER;
    hd INTEGER;
BEGIN
    SELECT abr.idfg, abr.idfd
    INTO monidfg, monidfd
    FROM abr
    WHERE id = monid;

    IF monid IS NULL THEN
        RETURN 0;
    ELSE
        IF monidfg IS NOT NULL AND monidfd IS NOT NULL THEN
            hg := hauteur(monidfg);
            hd := hauteur(monidfd);
            IF hg > hd THEN
                RETURN 1 + hg;
            ELSE
                RETURN 1 + hd;
            END IF;
        END IF;
        IF monidfg IS NULL AND monidfd IS NOT NULL THEN
            hd := hauteur(monidfd);
            RETURN 1 + hd;
        END IF;
        IF monidfg IS NOT NULL AND monidfd IS NULL THEN
            hg := hauteur(monidfg);
            RETURN 1 + hg;
        END IF;
        IF monidfg IS NULL AND monidfd IS NULL THEN
            RETURN 1;
        END IF;
    END IF;
END hauteur;
/

SELECT hauteur(1) FROM dual;

CREATE OR REPLACE FUNCTION hauteur(p_racine IN abr.id%TYPE)
RETURN INTEGER
IS
    v_fg abr.idfg%TYPE;
    v_fd abr.idfd%TYPE;
BEGIN
    -- Convention retenue :
    -- arbre vide = 0, feuille = 1 ; on compte les niveaux.
    -- En nombre de descentes, le même arbre non vide aurait hauteur - 1.
    IF p_racine IS NULL THEN
        RETURN 0;
    END IF;

    SELECT idfg, idfd INTO v_fg, v_fd
    FROM abr
    WHERE id = p_racine;

    RETURN 1 + GREATEST(hauteur(v_fg), hauteur(v_fd));
END;
/

SELECT hauteur(1) AS hauteur FROM dual;


-- ------------------------------------------------------------------------------------------------
-- E2Q1.4 — Lister les valeurs de l’arbre et leur nombre d’occurrences.

SELECT valeur, COUNT(*)
FROM abr
GROUP BY valeur;


-- ------------------------------------------------------------------------------------------------
-- E2Q1.5 — Construire un ABR contenant N valeurs entières positives aléatoires.

SET SERVEROUTPUT ON;

CREATE OR REPLACE PROCEDURE inserer(new_id INTEGER, valeur INTEGER, curr_id INTEGER)
AS
    v_idfg INTEGER;
    v_idfd INTEGER;
    v_root_valeur INTEGER;
BEGIN
    -- initialisation
    IF new_id = 1 THEN
        INSERT INTO abr VALUES (new_id, valeur, NULL, NULL);
        RETURN;
    END IF;

    -- récupère le noeud courant
    DBMS_OUTPUT.PUT_LINE('new_id=' || new_id || ', curr_id=' || curr_id);
    SELECT idfg, idfd, valeur INTO v_idfg, v_idfd, v_root_valeur FROM abr WHERE id = curr_id;

    IF v_root_valeur >= valeur THEN
        IF v_idfg IS NULL THEN
            INSERT INTO abr VALUES (new_id, valeur, NULL, NULL);
            UPDATE abr SET idfg = new_id WHERE id = curr_id;
            RETURN;
        ELSE
            inserer(new_id, valeur, v_idfg);
        END IF;
    ELSE
        IF v_idfd IS NULL THEN
            INSERT INTO abr VALUES (new_id, valeur, NULL, NULL);
            UPDATE abr SET idfd = new_id WHERE id = curr_id;
            RETURN;
        ELSE
            inserer(new_id, valeur, v_idfd);
        END IF;
    END IF;
END inserer;
/

CREATE OR REPLACE PROCEDURE creer_abr(N INTEGER)
AS
    rndm INTEGER;
BEGIN
    DELETE FROM abr; -- vider la base actuelle

    FOR i IN 1..N LOOP
        SELECT TRUNC(DBMS_RANDOM.VALUE(1, 100)) INTO rndm FROM dual; -- valeur aléatoire à insérer
        inserer(i, rndm, 1); -- on part toujours de la racine !
    END LOOP;
END creer_abr;
/

-- TESTS
-- temporairement désactiver le trigger pour gérer l'id
ALTER TRIGGER trig_abr_autoincrement DISABLE;
EXEC creer_abr(10);
SELECT * FROM abr; -- affichage
ALTER TRIGGER trig_abr_autoincrement ENABLE; -- réactiver le trigger


-- ------------------------------------------------------------------------------------------------
-- QUESTION 2 — CONTRAINTES SUR LA STRUCTURE ET LES VALEURS DE L’ARBRE
-- ------------------------------------------------------------------------------------------------

-- E2Q2.1 — Interdire la modification de l’identifiant d’un nœud.

CREATE OR REPLACE TRIGGER no_update_id
BEFORE UPDATE OF id ON abr
BEGIN
    RAISE_APPLICATION_ERROR(-20001, 'Update de id interdite!');
END;
/

UPDATE abr
SET id = 2
WHERE id = 1;

-- ORA-20001: Update de id interdite!


-- ------------------------------------------------------------------------------------------------
-- E2Q2.2 — Imposer des fils gauche et droit distincts pour un même nœud.

ALTER TABLE abr ADD CONSTRAINT chk_diff_fils CHECK (idfg != idfd);

INSERT INTO abr VALUES (4, 4, 4, 4);

-- ORA-02290: violation de contraintes (M2IT1.CHK_DIFF_FILS) de vérification


-- ------------------------------------------------------------------------------------------------
-- E2Q2.3 — À l’insertion, empêcher qu’un nœud ait deux parents.

CREATE OR REPLACE TRIGGER no_deux_parents
BEFORE INSERT ON abr
FOR EACH ROW
DECLARE
    v_idfg INTEGER := :NEW.idfg;
    v_idfd INTEGER := :NEW.idfd;
    cmpt_g INTEGER;
    cmpt_d INTEGER;
BEGIN
    SELECT COUNT(*) INTO cmpt_g
    FROM abr
    WHERE idfg = v_idfg OR idfd = v_idfg;

    IF cmpt_g >= 1 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Erreur! Le noeud ' || v_idfg || ' a déjà un parent !');
    END IF;

    SELECT COUNT(*) INTO cmpt_d
    FROM abr
    WHERE idfg = v_idfd OR idfd = v_idfd;

    IF cmpt_d >= 1 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Erreur! Le noeud ' || v_idfd || ' a déjà un parent !');
    END IF;
END;
/

INSERT INTO abr VALUES (6, 4, 4, NULL);
-- Erreur SQL : ORA-20002: Erreur! Le noeud 4 a déjà un parent !
INSERT INTO abr VALUES (6, 4, NULL, 5);
-- Erreur SQL : ORA-20003: Erreur! Le noeud 5 a déjà un parent !
INSERT INTO abr VALUES (6, 0, NULL, 1); -- passe ! 1 n'a pas de parent.


-- ------------------------------------------------------------------------------------------------
-- E2Q2.4 — Empêcher qu’un nœud soit son propre descendant.

-- on passe par une fonction récursive pour vérifier sur un id se retrouve lui-même
-- dans ses descendants
CREATE OR REPLACE FUNCTION is_in_descendants(test_id INTEGER, curr_id INTEGER)
RETURN BOOLEAN
IS
    v_idfg INTEGER;
    v_idfd INTEGER;
BEGIN
    IF curr_id IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT idfg, idfd INTO v_idfg, v_idfd FROM abr WHERE id = curr_id;
    IF v_idfg IS NULL AND v_idfd IS NULL THEN
        RETURN test_id = curr_id;
    ELSIF v_idfg IS NOT NULL AND v_idfd IS NULL THEN
        RETURN test_id = curr_id OR is_in_descendants(test_id, v_idfg);
    ELSIF v_idfg IS NULL AND v_idfd IS NOT NULL THEN
        RETURN test_id = curr_id OR is_in_descendants(test_id, v_idfd);
    ELSIF v_idfg IS NOT NULL AND v_idfd IS NOT NULL THEN
        RETURN test_id = curr_id
            OR is_in_descendants(test_id, v_idfg) OR is_in_descendants(test_id, v_idfd);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER no_propre_descendant
AFTER INSERT OR UPDATE OF idfg, idfd ON abr
BEGIN
    FOR i IN (SELECT id, idfg, idfd FROM abr) LOOP
        -- Partir des enfants pour ne pas se trouver soi-même immédiatement.
        IF is_in_descendants(i.id, i.idfg) OR is_in_descendants(i.id, i.idfd) THEN
            RAISE_APPLICATION_ERROR(-20004, 'Le noeud ' || i.id || ' est son propre descendant !');
        END IF;
    END LOOP;
END;
/

-- TEST
UPDATE abr SET idfg = 1 WHERE id = 4; -- fail attendu : 4 est un descendant de 1


-- ------------------------------------------------------------------------------------------------
-- E2Q2.5 — Imposer que toute valeur du sous-arbre gauche soit inférieure ou égale à celle du nœud.

-- meme technique que l’exo precedent : trigger appelle une fonction
CREATE OR REPLACE FUNCTION fg_smaller_than_root(curr_id INTEGER, val_max INTEGER)
RETURN BOOLEAN
IS
    v_idfg INTEGER;
    v_idfd INTEGER;
    v_val INTEGER;
BEGIN
    -- sous arbre vide respecte la condition
    IF curr_id IS NULL THEN
        RETURN TRUE;
    END IF;

    -- récupère les enfants
    SELECT valeur, idfg, idfd INTO v_val, v_idfg, v_idfd FROM abr WHERE id = curr_id;

    -- vérifier ce noeud, puis ses deux branches, en checkant la même valeur
    RETURN v_val <= val_max
        AND fg_smaller_than_root(v_idfg, val_max) AND fg_smaller_than_root(v_idfd, val_max);
END;
/

CREATE OR REPLACE TRIGGER no_valeur_gauche_superieure
AFTER INSERT OR UPDATE OF valeur, idfg, idfd ON abr
BEGIN
    FOR i IN (SELECT id, valeur, idfg FROM abr) LOOP
        -- On teste directement le fils gauche et toute son arborescence
        IF NOT fg_smaller_than_root(i.idfg, i.valeur) THEN
            RAISE_APPLICATION_ERROR(
                -20005, 'Une valeur du sous-arbre gauche depasse celle de ' || i.id);
        END IF;
    END LOOP;
END;
/

-- TEST
UPDATE abr SET valeur = 4 WHERE id = 4; -- fail attendu : 4 est dans le sous-arbre gauche de 1, qui vaut 3


-- ================================================================================================
-- EXERCICE 3 — DÉCLENCHEURS COMPOSÉS ET FILES D’ATTENTE
-- Gérer quatre files d’attente dans les tables utilisateurs et filedattente :
-- Attribuer les positions et les temps d’attente ; permettre au dernier d’une file d’en changer.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- E3Q1 — Calculer la position et le temps d’attente à l’insertion avec des déclencheurs classiques.
-- ------------------------------------------------------------------------------------------------

-- On applique le trigger sur un BEFORE INSERT pour modifier les lignes avant qu'elles soient insérées.
-- Le même processus sur un AFTER INSERT demande de lire les données d'une table en mutation.
CREATE OR REPLACE TRIGGER insert_file
BEFORE INSERT ON filedattente
FOR EACH ROW
DECLARE
    max_pos INTEGER;
    dernier_temps INTEGER;
    rdm INTEGER;
BEGIN
    -- Récupération de la dernière position
    -- (= 0 si c'est la première insertion de la file)
    SELECT NVL(MAX(position), 0)
    INTO max_pos
    FROM filedattente
    WHERE num_file = :NEW.num_file;

    -- Récupération du temps associé
    -- (= 0 si c'est la première insertion de la file)
    IF max_pos != 0 THEN
        SELECT temps_attente
        INTO dernier_temps
        FROM filedattente
        WHERE num_file = :NEW.num_file AND position = max_pos
        ;
    ELSE
        dernier_temps := 0;
    END IF;

    -- Temps supplémentaire aléatoire
    rdm := TRUNC(DBMS_RANDOM.VALUE(1, 11));

    -- Initialisation de la nouvelle ligne
    :NEW.position := max_pos + 1;
    :NEW.temps_attente := dernier_temps + rdm;
END;
/


-- ------------------------------------------------------------------------------------------------
-- E3Q2 — Tester les insertions dans les files d’attente.
-- ------------------------------------------------------------------------------------------------

-- Tests fournis :
insert into FileDAttente (num, num_file) values(1, 1);
insert into FileDAttente (num, num_file) values(2, 1);
insert into FileDAttente (num, num_file) values(3, 1);
insert into FileDAttente (num, num_file) values(4, 1);
insert into FileDAttente (num, num_file) values(5, 2);
insert into FileDAttente (num, num_file) values(6, 2);
insert into FileDAttente (num, num_file) values(7, 3);
insert into FileDAttente (num, num_file) values(8, 4);
insert into FileDAttente (num, num_file) values(9, 4);
insert into FileDAttente (num, num_file) values(10,4);

select * from filedattente;


-- Résultats :
-- NUM NUM_FILE POSITION TEMPS_ATTENTE 
-- --- -------- -------- ------------- 
-- 1   1        1        1
-- 2   1        2        6
-- 3   1        3        10
-- 4   1        4        19
-- 5   2        1        5
-- 6   2        2        8
-- 7   3        1        7
-- 8   4        1        8
-- 9   4        2        14
-- 10  4        3        21
-- 
-- Elapsed: 00:00:00.005
-- 10 rows selected. 

-- ------------------------------------------------------------------------------------------------
-- E3Q3 — Actualiser la position et le temps d’attente lors d’un changement de file.
-- ------------------------------------------------------------------------------------------------

-- On reprend exactement le même trigger que E3Q1, à une seule différence près...
CREATE OR REPLACE TRIGGER insert_file
BEFORE INSERT OR UPDATE OF num_file ON filedattente -- On rajoute une condition UPDATE d'activation !
FOR EACH ROW    -- Le reste du trigger est strictement identique à ce qu'on avait précédemment.
DECLARE
    max_pos INTEGER;
    dernier_temps INTEGER;
    rdm INTEGER;
BEGIN
    SELECT NVL(MAX(position), 0)
    INTO max_pos
    FROM filedattente
    WHERE num_file = :NEW.num_file;

    IF max_pos != 0 THEN
        SELECT temps_attente
        INTO dernier_temps
        FROM filedattente
        WHERE num_file = :NEW.num_file AND position = max_pos
        ;
    ELSE
        dernier_temps := 0;
    END IF;

    rdm := TRUNC(DBMS_RANDOM.VALUE(1, 11));

    :NEW.position := max_pos + 1;
    :NEW.temps_attente := dernier_temps + rdm;
END;
/


-- ------------------------------------------------------------------------------------------------
-- E3Q4 — Tester les changements de file et expliquer les erreurs de table en mutation.
-- ------------------------------------------------------------------------------------------------

UPDATE FILEDATTENTE
SET num_file = 2
WHERE num = 7;

-- ORA-04091 : table VINCENT_TOURENNE_SCHEMA_OHDI4.FILEDATTENTE is mutating, trigger/function may not see it

-- → Pourquoi ?
-- Le trigger utilise FOR EACH ROW : il consulte la table FILEDATTENTE pendant sa mutation.
-- Cela marchait sur un BEFORE INSERT car Oracle autorise une consultation exceptionnelle dans ce cas.
-- Cette exception ne s'applique pas à UPDATE, même avec BEFORE.

-- ------------------------------------------------------------------------------------------------
-- E3Q5 — Réécrire les automatisations avec des déclencheurs composés.
-- ------------------------------------------------------------------------------------------------


CREATE OR REPLACE TRIGGER insert_file
FOR INSERT OR UPDATE OF num_file ON filedattente
COMPOUND TRIGGER

    -- Informations mémorisées pour chaque file
    TYPE t_info IS RECORD (
        max_pos INTEGER,
        dernier_temps INTEGER
    );

    -- Tableau associatif indexé par numéro de file
    TYPE t_files IS TABLE OF t_info INDEX BY PLS_INTEGER;
    infos t_files;

    -- Avant toute insertion ou modification
    BEFORE STATEMENT IS
        info t_info;
    BEGIN
        -- Récupère la dernière entrée de chaque file
        FOR f IN (
            SELECT a.num_file, a.position, a.temps_attente
            FROM filedattente a
            WHERE a.position = (
                SELECT MAX(b.position)
                FROM filedattente b
                WHERE b.num_file = a.num_file
            )
        ) LOOP
            info.max_pos := f.position;
            info.dernier_temps := f.temps_attente;
            infos(f.num_file) := info;
        END LOOP;
    END BEFORE STATEMENT;

    -- Avant chaque ligne insérée ou modifiée
    BEFORE EACH ROW IS
        info t_info;
        rdm INTEGER;
    BEGIN
        -- Récupère les informations de la file concernée
        IF infos.EXISTS(:NEW.num_file) THEN
            info := infos(:NEW.num_file);
        ELSE
            info.max_pos := 0;
            info.dernier_temps := 0;
        END IF;

        rdm := TRUNC(DBMS_RANDOM.VALUE(1, 11));

        :NEW.position := info.max_pos + 1;
        :NEW.temps_attente := info.dernier_temps + rdm;

        -- Actualise les informations mémorisées
        info.max_pos := :NEW.position;
        info.dernier_temps := :NEW.temps_attente;
        infos(:NEW.num_file) := info;
    END BEFORE EACH ROW;

END insert_file;
/


-- ------------------------------------------------------------------------------------------------
-- E3Q6 — Vérifier les insertions et les changements de file avec les déclencheurs composés.
-- ------------------------------------------------------------------------------------------------

delete from FileDAttente;
insert into FileDAttente (num, num_file) values(1, 1);
insert into FileDAttente (num, num_file) values(2, 1);
insert into FileDAttente (num, num_file) values(3, 1);
insert into FileDAttente (num, num_file) values(4, 1);
insert into FileDAttente (num, num_file) values(5, 2);
insert into FileDAttente (num, num_file) values(6, 2);
insert into FileDAttente (num, num_file) values(7, 3);
insert into FileDAttente (num, num_file) values(8, 4);
insert into FileDAttente (num, num_file) values(9, 4);
insert into FileDAttente (num, num_file) values(10,4);

-- la file 3 doit devenir vide, 7 doit être en 3ème position de la file 2 
update FileDAttente set num_file = 2 where num = 7;
-- 10 doit devenir le 1er de la file 3, la file 4 ne doit plus avoir que 2 éléments 
update FileDAttente set num_file = 3 where num = 10;
-- 4 doit devenir le 4ème de la file 2, la file 1 ne doit plus avoir que 3 éléments
update FileDAttente set num_file = 2 where num = 4;


-- Résultats :
-- NUM NUM_FILE POSITION TEMPS_ATTENTE 
-- --- -------- -------- ------------- 
-- 1   1        1        9             
-- 2   1        2        11            
-- 3   1        3        16            
-- 4   2        4        12            
-- 5   2        1        1             
-- 6   2        2        3             
-- 7   2        3        8             
-- 8   4        1        4             
-- 9   4        2        6             
-- 10  3        1        7             
-- 
-- Elapsed: 00:00:00.004
-- 10 rows selected. 